#!/usr/bin/env bash
set -euo pipefail

# -------- util
w() { mkdir -p "$(dirname "$1")"; cat > "$1" <<'EOF'
'"$2"'
EOF
}
wraw() { mkdir -p "$(dirname "$1")"; cat > "$1" <<EOF
$2
EOF
}

proj=.
echo "[*] Scaffolding Spring Modulith modular monolith…"

# -------- settings.gradle
wraw "$proj/settings.gradle" "$(cat <<'EOF'
rootProject.name = 'ashen-store'
include 'app'
include 'domain:member', 'domain:catalog', 'domain:inventory', 'domain:order', 'domain:payment', 'domain:ranking', 'domain:readmodels', 'domain:review', 'domain:shared'
include 'common:event', 'common:outbox-message-relay', 'common:snowflake', 'common:data-serializer'
EOF
)"

# -------- root build.gradle
wraw "$proj/build.gradle" "$(cat <<'EOF'
plugins {
    id 'org.springframework.boot' version '3.3.2' apply false
    id 'io.spring.dependency-management' version '1.1.3' apply false
    id 'java' apply false
}

allprojects {
    group = 'ashen.store'
    version = '0.1.0-SNAPSHOT'
    repositories { mavenCentral() }
}

subprojects {
    apply plugin: 'java'
    apply plugin: 'io.spring.dependency-management'
    java { toolchain { languageVersion = JavaLanguageVersion.of(21) } }
    dependencyManagement {
        imports {
            mavenBom "org.springframework.boot:spring-boot-dependencies:3.3.2"
            mavenBom "org.springframework.modulith:spring-modulith-bom:1.4.2"
        }
    }
    tasks.withType(JavaCompile).configureEach {
        options.encoding = 'UTF-8'
    }
}
EOF
)"

# -------- :app build.gradle
wraw "$proj/app/build.gradle" "$(cat <<'EOF'
plugins { id 'org.springframework.boot' }
dependencies {
    implementation project(':domain:member')
    implementation project(':domain:catalog')
    implementation project(':domain:inventory')
    implementation project(':domain:order')
    implementation project(':domain:payment')
    implementation project(':domain:ranking')
    implementation project(':domain:readmodels')
    implementation project(':domain:review')
    implementation project(':domain:shared')
    implementation project(':common:event')
    implementation project(':common:outbox-message-relay')
    implementation project(':common:snowflake')
    implementation project(':common:data-serializer')

    implementation 'org.springframework.boot:spring-boot-starter-web'
    implementation 'org.springframework.boot:spring-boot-starter-actuator'
    implementation 'org.springframework.boot:spring-boot-starter-data-jpa'
    implementation 'org.springframework.boot:spring-boot-starter-data-redis'
    implementation 'org.springframework.boot:spring-boot-starter-security'
    implementation 'org.springframework.kafka:spring-kafka'
    implementation 'org.springframework.modulith:spring-modulith-starter-jdbc'
    runtimeOnly 'com.mysql:mysql-connector-j:8.4.0'

    testImplementation 'org.springframework.boot:spring-boot-starter-test'
    testImplementation 'org.testcontainers:mysql'
    testImplementation 'org.testcontainers:kafka'
    testImplementation 'org.testcontainers:toxiproxy'
}
EOF
)"

# -------- :app application.ymls
wraw "$proj/app/src/main/resources/application.yml" "$(cat <<'EOF'
spring:
  application.name: ashen-store
  datasource:
    url: jdbc:mysql://localhost:3306/ashen_store
    username: root
    password: root
    driver-class-name: com.mysql.cj.jdbc.Driver
  jpa:
    hibernate.ddl-auto: update
    properties.hibernate.format_sql: true
  redis:
    host: localhost
    port: 6379
  kafka.bootstrap-servers: localhost:9092
  modulith:
    events:
      jdbc:
        schema-initialization.enabled: true
      republish-outstanding-events-on-restart: true
      completion-mode: DELETE
server:
  port: 8080
EOF
)"
wraw "$proj/app/src/main/resources/application-monolith.yml" "spring:\n  profiles: monolith\n"
wraw "$proj/app/src/main/resources/application-msa.yml" "$(cat <<'EOF'
spring:
  profiles: msa
inventory.base-url: http://localhost:9000
order.base-url: http://localhost:9001
payment.base-url: http://localhost:9002
EOF
)"

# -------- :app main & bindings
wraw "$proj/app/src/main/java/ashen/store/AppApplication.java" "$(cat <<'EOF'
package ashen.store;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableScheduling;

@SpringBootApplication
@EnableScheduling
public class AppApplication {
  public static void main(String[] args) {
    SpringApplication.run(AppApplication.class, args);
  }
}
EOF
)"

wraw "$proj/app/src/main/java/ashen/store/MonolithBindings.java" "$(cat <<'EOF'
package ashen.store;

import org.springframework.context.annotation.*;
import ashen.store.inventory.InventoryApi;
import ashen.store.inventory.app.InventoryApplicationService;
import ashen.store.order.OrderApi;
import ashen.store.order.app.OrderApplicationService;
import ashen.store.payment.PaymentApi;
import ashen.store.payment.app.PaymentApplicationService;
// TODO: add other APIs similarly (member, catalog, review, readmodels, ranking)

@Configuration
@Profile("monolith")
class MonolithBindings {

  @Bean InventoryApi inventoryApi(InventoryApplicationService useCase) {
    return new InventoryApi() { public InventoryUseCase useCase() { return useCase; } };
  }
  @Bean OrderApi orderApi(OrderApplicationService useCase) {
    return new OrderApi() { public OrderUseCase useCase() { return useCase; } };
  }
  @Bean PaymentApi paymentApi(PaymentApplicationService useCase) {
    return new PaymentApi() { public PaymentUseCase useCase() { return useCase; } };
  }
}
EOF
)"

wraw "$proj/app/src/main/java/ashen/store/MsaBindings.java" "$(cat <<'EOF'
package ashen.store;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.*;
import org.springframework.web.client.RestClient;
import org.springframework.web.service.invoker.*;
import ashen.store.inventory.InventoryApi;
import ashen.store.order.OrderApi;
import ashen.store.payment.PaymentApi;

@Configuration
@Profile("msa")
class MsaBindings {
  private <T> T client(RestClient.Builder b, String baseUrl, Class<T> clz) {
    RestClient rc = b.baseUrl(baseUrl).build();
    HttpServiceProxyFactory f = HttpServiceProxyFactory.builderFor(RestClientAdapter.create(rc)).build();
    return f.createClient(clz);
  }

  @Bean InventoryApi inventoryClient(RestClient.Builder b, @Value("${inventory.base-url}") String url) {
    return client(b, url, InventoryApi.class);
  }
  @Bean OrderApi orderClient(RestClient.Builder b, @Value("${order.base-url}") String url) {
    return client(b, url, OrderApi.class);
  }
  @Bean PaymentApi paymentClient(RestClient.Builder b, @Value("${payment.base-url}") String url) {
    return client(b, url, PaymentApi.class);
  }
}
EOF
)"

# -------- helper to create domain module build.gradle
mkDomainGradle() {
wraw "$proj/domain/$1/build.gradle" "$(cat <<'EOF'
dependencies {
  implementation 'org.springframework.modulith:spring-modulith-core'
  implementation 'org.springframework.boot:spring-boot-starter-data-jpa'
}
EOF
)"
}

# -------- domain:member
mkDomainGradle member
wraw "$proj/domain/member/src/main/java/ashen/store/member/package-info.java" "@org.springframework.modulith.ApplicationModule(name=\"member\")\n@org.springframework.modulith.NamedInterface(\"api\")\npackage ashen.store.member;\n"
wraw "$proj/domain/member/src/main/java/ashen/store/member/MemberApi.java" "$(cat <<'EOF'
package ashen.store.member;

import org.springframework.web.bind.annotation.*;
import org.springframework.web.service.annotation.*;
import java.util.Optional;

@RequestMapping("/v1/members")
@HttpExchange("/v1/members")
public interface MemberApi {
  @PostMapping @PostExchange
  default Member register(@RequestBody CreateMemberCommand cmd) { return useCase().register(cmd); }
  @GetMapping("/{id}") @GetExchange("/{id}")
  default Optional<Member> get(@PathVariable Long id) { return useCase().findById(id); }

  MemberUseCase useCase();

  record CreateMemberCommand(String userId, String name, String email) {}
  interface MemberUseCase {
    Member register(CreateMemberCommand cmd);
    Optional<Member> findById(Long id);
  }
}
EOF
)"
wraw "$proj/domain/member/src/main/java/ashen/store/member/app/MemberApplicationService.java" "$(cat <<'EOF'
package ashen.store.member.app;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.util.Optional;
import ashen.store.member.MemberApi.MemberUseCase;
import ashen.store.member.MemberApi.CreateMemberCommand;
import ashen.store.member.domain.Member;
import ashen.store.member.domain.MemberRepository;

@Service
public class MemberApplicationService implements MemberUseCase {
  private final MemberRepository repo;
  public MemberApplicationService(MemberRepository repo){ this.repo = repo; }

  @Transactional public Member register(CreateMemberCommand cmd){
    return repo.save(new Member(cmd.userId(), cmd.name(), cmd.email()));
  }
  @Transactional(readOnly=true) public Optional<Member> findById(Long id){ return repo.findById(id); }
}
EOF
)"
wraw "$proj/domain/member/src/main/java/ashen/store/member/domain/Member.java" "$(cat <<'EOF'
package ashen.store.member.domain;

import jakarta.persistence.*;
import java.time.Instant;

@Entity
@Table(name="members", indexes = { @Index(name="idx_member_user_id", columnList="userId", unique=true) })
public class Member {
  @Id @GeneratedValue(strategy=GenerationType.IDENTITY) private Long id;
  @Column(nullable=false, unique=true) private String userId;
  private String name; private String email;
  private Instant createdAt = Instant.now();
  protected Member(){}
  public Member(String userId, String name, String email){ this.userId=userId; this.name=name; this.email=email; }
  public Long getId(){ return id; } public String getUserId(){ return userId; } public String getName(){ return name; }
}
EOF
)"
wraw "$proj/domain/member/src/main/java/ashen/store/member/domain/MemberRepository.java" "package ashen.store.member.domain;\nimport java.util.*;\npublic interface MemberRepository{ Optional<Member> findById(Long id); Member save(Member m); }\n"
wraw "$proj/domain/member/src/main/java/ashen/store/member/persistence/rdb/MemberRepositoryJpa.java" "package ashen.store.member.persistence.rdb;\nimport ashen.store.member.domain.*;\nimport org.springframework.data.jpa.repository.JpaRepository;\npublic interface MemberRepositoryJpa extends MemberRepository, JpaRepository<Member,Long>{}\n"

# -------- domain:catalog
mkDomainGradle catalog
wraw "$proj/domain/catalog/src/main/java/ashen/store/catalog/package-info.java" "@org.springframework.modulith.ApplicationModule(name=\"catalog\")\n@org.springframework.modulith.NamedInterface(\"api\")\npackage ashen.store.catalog;\n"
wraw "$proj/domain/catalog/src/main/java/ashen/store/catalog/CatalogApi.java" "$(cat <<'EOF'
package ashen.store.catalog;

import org.springframework.web.bind.annotation.*;
import org.springframework.web.service.annotation.*;
import java.util.List;

@RequestMapping("/v1/products")
@HttpExchange("/v1/products")
public interface CatalogApi {
  @GetMapping @GetExchange
  default List<Product> list(@RequestParam(required=false) String category) {
    return useCase().findProducts(category);
  }
  CatalogUseCase useCase();
  interface CatalogUseCase { List<Product> findProducts(String category); }
}
EOF
)"
wraw "$proj/domain/catalog/src/main/java/ashen/store/catalog/app/CatalogApplicationService.java" "$(cat <<'EOF'
package ashen.store.catalog.app;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.util.List;
import ashen.store.catalog.CatalogApi.CatalogUseCase;
import ashen.store.catalog.domain.*;

@Service
public class CatalogApplicationService implements CatalogUseCase {
  private final ProductRepository repo;
  public CatalogApplicationService(ProductRepository repo){ this.repo = repo; }
  @Transactional(readOnly=true) public List<Product> findProducts(String category){
    return category!=null ? repo.findByCategory(category) : repo.findAll();
  }
}
EOF
)"
wraw "$proj/domain/catalog/src/main/java/ashen/store/catalog/domain/Product.java" "$(cat <<'EOF'
package ashen.store.catalog.domain;

import jakarta.persistence.*;
import java.time.Instant;

@Entity
@Table(name="products", indexes = {
  @Index(name="idx_product_category_price", columnList="category, price"),
  @Index(name="idx_product_created_at", columnList="createdAt DESC")
})
public class Product {
  @Id @GeneratedValue(strategy=GenerationType.IDENTITY) private Long id;
  @Column(nullable=false) private String name;
  private String category; private double price; private Instant createdAt = Instant.now();
  protected Product() {}
  public Product(String name,String category,double price){ this.name=name; this.category=category; this.price=price; }
  public Long getId(){ return id; } public String getName(){ return name; }
}
EOF
)"
wraw "$proj/domain/catalog/src/main/java/ashen/store/catalog/domain/ProductRepository.java" "package ashen.store.catalog.domain;\nimport java.util.*;\npublic interface ProductRepository{ List<Product> findAll(); List<Product> findByCategory(String c); Product save(Product p);} \n"
wraw "$proj/domain/catalog/src/main/java/ashen/store/catalog/persistence/rdb/ProductRepositoryJpa.java" "package ashen.store.catalog.persistence.rdb;\nimport ashen.store.catalog.domain.*;\nimport org.springframework.data.jpa.repository.*;\nimport java.util.*;\npublic interface ProductRepositoryJpa extends ProductRepository, JpaRepository<Product,Long>{ List<Product> findByCategory(String category);} \n"

# -------- domain:inventory
mkDomainGradle inventory
wraw "$proj/domain/inventory/src/main/java/ashen/store/inventory/package-info.java" "@org.springframework.modulith.ApplicationModule(name=\"inventory\")\n@org.springframework.modulith.NamedInterface(\"api\")\npackage ashen.store.inventory;\n"
wraw "$proj/domain/inventory/src/main/java/ashen/store/inventory/InventoryApi.java" "$(cat <<'EOF'
package ashen.store.inventory;

import org.springframework.web.bind.annotation.*;
import org.springframework.web.service.annotation.*;

@RequestMapping("/v1/inventory")
@HttpExchange("/v1/inventory")
public interface InventoryApi {
  @PostMapping("/reserve") @PostExchange("/reserve")
  default ReserveResult reserve(@RequestBody ReserveCommand cmd){
    boolean ok = useCase().reserve(cmd.productId(), cmd.qty());
    return new ReserveResult(ok, ok? null : "INSUFFICIENT");
  }
  @PostMapping("/release") @PostExchange("/release")
  default void release(@RequestBody ReleaseCommand cmd){ useCase().release(cmd.productId(), cmd.qty()); }

  InventoryUseCase useCase();
  record ReserveCommand(Long productId, int qty) {}
  record ReserveResult(boolean ok, String reason) {}
  record ReleaseCommand(Long productId, int qty) {}

  interface InventoryUseCase { boolean reserve(Long productId, int qty); void release(Long productId, int qty); }
}
EOF
)"
wraw "$proj/domain/inventory/src/main/java/ashen/store/inventory/app/InventoryApplicationService.java" "$(cat <<'EOF'
package ashen.store.inventory.app;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import ashen.store.inventory.InventoryApi.InventoryUseCase;
import ashen.store.inventory.domain.*;
import org.springframework.dao.OptimisticLockingFailureException;

@Service
public class InventoryApplicationService implements InventoryUseCase {
  private final InventoryRepository repo;
  public InventoryApplicationService(InventoryRepository repo){ this.repo = repo; }

  @Transactional
  public boolean reserve(Long productId, int qty){
    for(int attempt=1; attempt<=3; attempt++){
      Inventory inv = repo.findByProductId(productId).orElseThrow(() -> new IllegalStateException("No inventory"));
      if (inv.getQuantity() < qty) return false;
      inv.setQuantity(inv.getQuantity()-qty);
      try { repo.save(inv); return true; }
      catch(OptimisticLockingFailureException e){
        try { Thread.sleep(attempt==1?50:attempt==2?100:200); } catch (InterruptedException ie){ Thread.currentThread().interrupt(); }
      }
    }
    return false;
  }

  @Transactional
  public void release(Long productId, int qty){
    repo.findByProductId(productId).ifPresent(inv -> { inv.setQuantity(inv.getQuantity()+qty); repo.save(inv); });
  }
}
EOF
)"
wraw "$proj/domain/inventory/src/main/java/ashen/store/inventory/domain/Inventory.java" "$(cat <<'EOF'
package ashen.store.inventory.domain;

import jakarta.persistence.*;

@Entity
@Table(name="inventory", indexes = { @Index(name="idx_inventory_product_id", columnList="productId", unique=true) })
public class Inventory {
  @Id @GeneratedValue(strategy=GenerationType.IDENTITY) private Long id;
  @Column(nullable=false, unique=true) private Long productId;
  private int quantity;
  @Version private int version;
  protected Inventory(){}
  public Inventory(Long productId,int quantity){ this.productId=productId; this.quantity=quantity; }
  public Long getProductId(){ return productId; } public int getQuantity(){ return quantity; }
  public void setQuantity(int q){ this.quantity=q; }
}
EOF
)"
wraw "$proj/domain/inventory/src/main/java/ashen/store/inventory/domain/InventoryRepository.java" "package ashen.store.inventory.domain;\nimport java.util.*;\npublic interface InventoryRepository{ Optional<Inventory> findByProductId(Long productId); Inventory save(Inventory inv);} \n"
wraw "$proj/domain/inventory/src/main/java/ashen/store/inventory/persistence/rdb/InventoryRepositoryJpa.java" "package ashen.store.inventory.persistence.rdb;\nimport ashen.store.inventory.domain.*;\nimport org.springframework.data.jpa.repository.*;\nimport java.util.*;\npublic interface InventoryRepositoryJpa extends InventoryRepository, JpaRepository<Inventory,Long>{ Optional<Inventory> findByProductId(Long productId);} \n"

# -------- domain:order
mkDomainGradle order
wraw "$proj/domain/order/src/main/java/ashen/store/order/package-info.java" "@org.springframework.modulith.ApplicationModule(name=\"order\")\n@org.springframework.modulith.NamedInterface(\"api\")\npackage ashen.store.order;\n"
wraw "$proj/domain/order/src/main/java/ashen/store/order/OrderApi.java" "$(cat <<'EOF'
package ashen.store.order;

import org.springframework.web.bind.annotation.*;
import org.springframework.web.service.annotation.*;
import org.springframework.http.*;

@RequestMapping("/v1/orders")
@HttpExchange("/v1/orders")
public interface OrderApi {
  @PostMapping @PostExchange
  default ResponseEntity<OrderResult> place(@RequestBody PlaceOrderCommand cmd,
                                            @RequestHeader(name="Idempotency-Key", required=false) String key){
    OrderResult r = useCase().placeOrder(cmd, key);
    return ResponseEntity.status(r.created()? HttpStatus.CREATED : HttpStatus.OK).body(r);
  }
  OrderUseCase useCase();

  record PlaceOrderCommand(Long memberId, Long productId, int quantity, double price) {}
  record OrderResult(boolean created, String orderId, String message) {}
  interface OrderUseCase { OrderResult placeOrder(PlaceOrderCommand cmd, String idempotencyKey); }
}
EOF
)"
wraw "$proj/domain/order/src/main/java/ashen/store/order/app/OrderApplicationService.java" "$(cat <<'EOF'
package ashen.store.order.app;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.util.UUID;
import ashen.store.order.OrderApi.*;
import ashen.store.order.domain.*;
import ashen.store.inventory.InventoryApi;
import ashen.store.payment.PaymentApi;
import ashen.store.outbox.*;

@Service
public class OrderApplicationService implements OrderUseCase {
  private final OrderRepository orders;
  private final InventoryApi inventory;
  private final PaymentApi payment;
  private final OutboxRepository outbox;

  public OrderApplicationService(OrderRepository o, InventoryApi i, PaymentApi p, OutboxRepository ob){
    this.orders=o; this.inventory=i; this.payment=p; this.outbox=ob;
  }

  @Transactional
  public OrderResult placeOrder(PlaceOrderCommand cmd, String idem){
    if (idem!=null){
      var existing = orders.findByIdempotencyKey(idem).orElse(null);
      if (existing!=null) return new OrderResult(false, existing.getOrderId(), "DUPLICATE");
    }
    boolean reserved = inventory.reserve(new InventoryApi.ReserveCommand(cmd.productId(), cmd.quantity())).ok();
    if (!reserved) return new OrderResult(false, null, "INSUFFICIENT_STOCK");
    var pay = payment.requestPayment(new PaymentApi.PaymentRequest(cmd.memberId(), cmd.price()*cmd.quantity()));
    if (!pay.success()) {
      inventory.release(new InventoryApi.ReleaseCommand(cmd.productId(), cmd.quantity()));
      return new OrderResult(false, null, "PAYMENT_FAILED");
    }
    Order saved = orders.save(new Order(cmd.memberId(), cmd.productId(), cmd.quantity(), cmd.price()*cmd.quantity(), idem));
    outbox.save(new Outbox(new OrderPlaced(saved.getId(), saved.getMemberId(), saved.getProductId(), saved.getTotalPrice())));
    return new OrderResult(true, saved.getOrderId(), "ORDER_PLACED");
  }
}
EOF
)"
wraw "$proj/domain/order/src/main/java/ashen/store/order/domain/Order.java" "$(cat <<'EOF'
package ashen.store.order.domain;

import jakarta.persistence.*;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name="orders", indexes={
  @Index(name="idx_orders_member_created", columnList="memberId, createdAt DESC"),
  @Index(name="idx_orders_idempotency_key", columnList="idempotencyKey", unique=true)
})
public class Order {
  @Id @GeneratedValue(strategy=GenerationType.UUID) private UUID id;
  private Long memberId; private Long productId; private int quantity; private double totalPrice;
  private Instant createdAt = Instant.now();
  @Column(unique=true, updatable=false) private String idempotencyKey;

  protected Order(){}
  public Order(Long memberId, Long productId, int quantity, double totalPrice, String idem){
    this.memberId=memberId; this.productId=productId; this.quantity=quantity; this.totalPrice=totalPrice; this.idempotencyKey=idem;
  }
  public UUID getId(){ return id; } public String getOrderId(){ return id.toString(); }
  public Long getMemberId(){ return memberId; } public Long getProductId(){ return productId; } public double getTotalPrice(){ return totalPrice; }
}
EOF
)"
wraw "$proj/domain/order/src/main/java/ashen/store/order/domain/OrderRepository.java" "package ashen.store.order.domain;\nimport java.util.*;\nimport java.util.UUID;\npublic interface OrderRepository{ Order save(Order o); Optional<Order> findByIdempotencyKey(String k); }\n"
wraw "$proj/domain/order/src/main/java/ashen/store/order/persistence/rdb/OrderRepositoryJpa.java" "package ashen.store.order.persistence.rdb;\nimport ashen.store.order.domain.*;\nimport org.springframework.data.jpa.repository.*;\nimport java.util.*; import java.util.UUID;\npublic interface OrderRepositoryJpa extends OrderRepository, JpaRepository<Order,UUID>{ Optional<Order> findByIdempotencyKey(String idempotencyKey);} \n"
wraw "$proj/domain/order/src/main/java/ashen/store/order/domain/OrderPlaced.java" "$(cat <<'EOF'
package ashen.store.order.domain;

import java.util.UUID;
import ashen.store.event.Topic;

@Topic("orders.order-placed")
public class OrderPlaced {
  private UUID orderId; private Long memberId; private Long productId; private double totalPrice;
  public OrderPlaced(UUID orderId, Long memberId, Long productId, double totalPrice){
    this.orderId=orderId; this.memberId=memberId; this.productId=productId; this.totalPrice=totalPrice;
  }
  public UUID getOrderId(){ return orderId; } public Long getMemberId(){ return memberId; }
  public Long getProductId(){ return productId; } public double getTotalPrice(){ return totalPrice; }
}
EOF
)"

# -------- domain:payment
mkDomainGradle payment
wraw "$proj/domain/payment/src/main/java/ashen/store/payment/package-info.java" "@org.springframework.modulith.ApplicationModule(name=\"payment\")\n@org.springframework.modulith.NamedInterface(\"api\")\npackage ashen.store.payment;\n"
wraw "$proj/domain/payment/src/main/java/ashen/store/payment/PaymentApi.java" "$(cat <<'EOF'
package ashen.store.payment;

import org.springframework.web.bind.annotation.*;
import org.springframework.web.service.annotation.*;

@RequestMapping("/v1/payments")
@HttpExchange("/v1/payments")
public interface PaymentApi {
  @PostMapping("/request") @PostExchange("/request")
  default PaymentResult requestPayment(@RequestBody PaymentRequest req){ return useCase().processPayment(req); }

  PaymentUseCase useCase();
  record PaymentRequest(Long memberId, double amount) {}
  record PaymentResult(boolean success, String transactionId) {}
  interface PaymentUseCase { PaymentResult processPayment(PaymentRequest req); }
}
EOF
)"
wraw "$proj/domain/payment/src/main/java/ashen/store/payment/app/PaymentApplicationService.java" "$(cat <<'EOF'
package ashen.store.payment.app;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.util.UUID;
import ashen.store.payment.PaymentApi.*;

@Service
public class PaymentApplicationService implements PaymentUseCase {
  @Transactional public PaymentResult processPayment(PaymentRequest req){
    return new PaymentResult(true, UUID.randomUUID().toString());
  }
}
EOF
)"

# -------- domain:ranking
mkDomainGradle ranking
wraw "$proj/domain/ranking/src/main/java/ashen/store/ranking/package-info.java" "@org.springframework.modulith.ApplicationModule(name=\"ranking\")\n@org.springframework.modulith.NamedInterface(\"api\")\npackage ashen.store.ranking;\n"
wraw "$proj/domain/ranking/src/main/java/ashen/store/ranking/RankingApi.java" "$(cat <<'EOF'
package ashen.store.ranking;

import org.springframework.web.bind.annotation.*;
import org.springframework.web.service.annotation.*;
import java.util.List;

@RequestMapping("/v1/rankings")
@HttpExchange("/v1/rankings")
public interface RankingApi {
  @GetMapping("/top-products") @GetExchange("/top-products")
  default List<ProductRank> top(@RequestParam(defaultValue="10") int count){ return useCase().getTopProducts(count); }
  RankingUseCase useCase();
  record ProductRank(Long productId, long orderCount){}
  interface RankingUseCase { List<ProductRank> getTopProducts(int count); }
}
EOF
)"
wraw "$proj/domain/ranking/src/main/java/ashen/store/ranking/app/RankingApplicationService.java" "$(cat <<'EOF'
package ashen.store.ranking.app;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.util.List;
import ashen.store.ranking.RankingApi.*;
import ashen.store.ranking.domain.RankingRepository;

@Service
public class RankingApplicationService implements RankingUseCase {
  private final RankingRepository repo;
  public RankingApplicationService(RankingRepository repo){ this.repo = repo; }
  @Transactional(readOnly=true) public List<ProductRank> getTopProducts(int count){ return repo.findTopProducts(count); }
}
EOF
)"
wraw "$proj/domain/ranking/src/main/java/ashen/store/ranking/domain/RankingRepository.java" "package ashen.store.ranking.domain;\nimport java.util.*;\nimport ashen.store.ranking.RankingApi.ProductRank;\npublic interface RankingRepository{ void incrementProductOrderCount(Long productId); List<ProductRank> findTopProducts(int count);} \n"
wraw "$proj/domain/ranking/src/main/java/ashen/store/ranking/messaging/OrderPlacedListener.java" "$(cat <<'EOF'
package ashen.store.ranking.messaging;

import org.springframework.stereotype.Component;
import org.springframework.modulith.ApplicationModuleListener;
import ashen.store.order.domain.OrderPlaced;
import ashen.store.ranking.domain.RankingRepository;

@Component
public class OrderPlacedListener {
  private final RankingRepository repo;
  public OrderPlacedListener(RankingRepository repo){ this.repo = repo; }
  @ApplicationModuleListener
  void on(OrderPlaced e){ repo.incrementProductOrderCount(e.getProductId()); }
}
EOF
)"

# -------- domain:readmodels
mkDomainGradle readmodels
wraw "$proj/domain/readmodels/src/main/java/ashen/store/readmodels/package-info.java" "@org.springframework.modulith.ApplicationModule(name=\"readmodels\")\n@org.springframework.modulith.NamedInterface(\"api\")\npackage ashen.store.readmodels;\n"
wraw "$proj/domain/readmodels/src/main/java/ashen/store/readmodels/ReadmodelsApi.java" "$(cat <<'EOF'
package ashen.store.readmodels;

import org.springframework.web.bind.annotation.*;
import org.springframework.web.service.annotation.*;
import java.util.concurrent.CompletableFuture;

@RequestMapping("/v1/readmodels")
@HttpExchange("/v1/readmodels")
public interface ReadmodelsApi {
  @GetMapping("/product-details/{productId}") @GetExchange("/product-details/{productId}")
  default CompletableFuture<ProductDetails> get(@PathVariable Long productId){ return useCase().getProductDetails(productId); }
  ReadmodelsUseCase useCase();
  record ProductDetails(Long productId, String name, String category, double price, int reviewCount, double averageRating){}
  interface ReadmodelsUseCase { CompletableFuture<ProductDetails> getProductDetails(Long productId); }
}
EOF
)"
wraw "$proj/domain/readmodels/src/main/java/ashen/store/readmodels/app/ReadmodelsApplicationService.java" "$(cat <<'EOF'
package ashen.store.readmodels.app;

import org.springframework.stereotype.Service;
import java.util.concurrent.CompletableFuture;
import ashen.store.readmodels.ReadmodelsApi.*;
import ashen.store.readmodels.persistence.CacheStore;

@Service
public class ReadmodelsApplicationService implements ReadmodelsUseCase {
  private final CacheStore cache;
  public ReadmodelsApplicationService(CacheStore cache){ this.cache = cache; }
  public CompletableFuture<ProductDetails> getProductDetails(Long productId){ return cache.getProductDetails(productId); }
}
EOF
)"
wraw "$proj/domain/readmodels/src/main/java/ashen/store/readmodels/persistence/CacheStore.java" "$(cat <<'EOF'
package ashen.store.readmodels.persistence;

import org.springframework.stereotype.Component;
import java.util.concurrent.*;
import ashen.store.readmodels.ReadmodelsApi.ProductDetails;

@Component
public class CacheStore {
  private final ConcurrentHashMap<Long, CompletableFuture<ProductDetails>> inFlight = new ConcurrentHashMap<>();
  public CompletableFuture<ProductDetails> getProductDetails(Long productId){
    ProductDetails cached = null; // TODO redis cache wiring later
    if (cached!=null) return CompletableFuture.completedFuture(cached);
    return inFlight.computeIfAbsent(productId, id ->
      CompletableFuture.supplyAsync(() -> {
        ProductDetails d = new ProductDetails(id, "Dummy","Category",0.0,0,0.0);
        inFlight.remove(id);
        return d;
      })
    );
  }
  public void evictProduct(Long productId){ /* TODO redis delete */ }
}
EOF
)"
wraw "$proj/domain/readmodels/src/main/java/ashen/store/readmodels/messaging/ReviewCreatedListener.java" "$(cat <<'EOF'
package ashen.store.readmodels.messaging;

import org.springframework.stereotype.Component;
import org.springframework.modulith.ApplicationModuleListener;
import ashen.store.review.domain.ReviewCreated;
import ashen.store.readmodels.persistence.CacheStore;

@Component
public class ReviewCreatedListener {
  private final CacheStore cache;
  public ReviewCreatedListener(CacheStore cache){ this.cache = cache; }
  @ApplicationModuleListener
  void on(ReviewCreated e){ cache.evictProduct(e.getProductId()); }
}
EOF
)"

# -------- domain:review
mkDomainGradle review
wraw "$proj/domain/review/src/main/java/ashen/store/review/package-info.java" "@org.springframework.modulith.ApplicationModule(name=\"review\")\n@org.springframework.modulith.NamedInterface(\"api\")\npackage ashen.store.review;\n"
wraw "$proj/domain/review/src/main/java/ashen/store/review/ReviewApi.java" "$(cat <<'EOF'
package ashen.store.review;

import org.springframework.web.bind.annotation.*;
import org.springframework.web.service.annotation.*;
import org.springframework.http.ResponseEntity;
import java.util.UUID;

@RequestMapping("/v1/reviews")
@HttpExchange("/v1/reviews")
public interface ReviewApi {
  @PostMapping @PostExchange
  default ResponseEntity<ReviewResponse> add(@RequestBody CreateReviewCommand cmd){
    var res = useCase().addReview(cmd);
    return ResponseEntity.status(201).body(res);
  }
  ReviewUseCase useCase();

  record CreateReviewCommand(Long productId, Long memberId, String content, int rating){}
  record ReviewResponse(UUID reviewId, Long productId, Long memberId, String content, int rating){}
  interface ReviewUseCase { ReviewResponse addReview(CreateReviewCommand cmd); }
}
EOF
)"
wraw "$proj/domain/review/src/main/java/ashen/store/review/app/ReviewApplicationService.java" "$(cat <<'EOF'
package ashen.store.review.app;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import ashen.store.review.ReviewApi.*;
import ashen.store.review.domain.*;
import ashen.store.outbox.*;

@Service
public class ReviewApplicationService implements ReviewUseCase {
  private final ReviewRepository repo; private final OutboxRepository outbox;
  public ReviewApplicationService(ReviewRepository repo, OutboxRepository outbox){ this.repo=repo; this.outbox=outbox; }

  @Transactional
  public ReviewResponse addReview(CreateReviewCommand cmd){
    Review saved = repo.save(new Review(cmd.productId(), cmd.memberId(), cmd.content(), cmd.rating()));
    outbox.save(new Outbox(new ReviewCreated(saved.getId(), saved.getProductId(), saved.getMemberId(), saved.getRating())));
    return new ReviewResponse(saved.getId(), saved.getProductId(), saved.getMemberId(), saved.getContent(), saved.getRating());
  }
}
EOF
)"
wraw "$proj/domain/review/src/main/java/ashen/store/review/domain/Review.java" "$(cat <<'EOF'
package ashen.store.review.domain;

import jakarta.persistence.*; import java.util.UUID; import java.time.Instant;
@Entity
@Table(name="reviews", indexes = {
  @Index(name="idx_review_product_created", columnList="productId, createdAt DESC"),
  @Index(name="idx_review_member_created", columnList="memberId, createdAt DESC")
})
public class Review {
  @Id @GeneratedValue(strategy=GenerationType.UUID) private UUID id;
  private Long productId; private Long memberId; private String content; private int rating;
  private Instant createdAt = Instant.now();
  protected Review(){}
  public Review(Long productId, Long memberId, String content, int rating){
    this.productId=productId; this.memberId=memberId; this.content=content; this.rating=rating;
  }
  public UUID getId(){ return id; } public Long getProductId(){ return productId; } public Long getMemberId(){ return memberId; }
  public String getContent(){ return content; } public int getRating(){ return rating; }
}
EOF
)"
wraw "$proj/domain/review/src/main/java/ashen/store/review/domain/ReviewRepository.java" "package ashen.store.review.domain;\nimport java.util.*; import java.util.UUID;\npublic interface ReviewRepository{ Review save(Review r); List<Review> findByProductId(Long productId);} \n"
wraw "$proj/domain/review/src/main/java/ashen/store/review/persistence/rdb/ReviewRepositoryJpa.java" "package ashen.store.review.persistence.rdb;\nimport ashen.store.review.domain.*; import org.springframework.data.jpa.repository.*; import java.util.*; import java.util.UUID;\npublic interface ReviewRepositoryJpa extends ReviewRepository, JpaRepository<Review,UUID>{ List<Review> findByProductId(Long productId);} \n"
wraw "$proj/domain/review/src/main/java/ashen/store/review/domain/ReviewCreated.java" "$(cat <<'EOF'
package ashen.store.review.domain;

import java.util.UUID;
import ashen.store.event.Topic;

@Topic("reviews.review-created")
public class ReviewCreated {
  private UUID reviewId; private Long productId; private Long memberId; private int rating;
  public ReviewCreated(UUID id, Long productId, Long memberId, int rating){
    this.reviewId=id; this.productId=productId; this.memberId=memberId; this.rating=rating;
  }
  public UUID getReviewId(){ return reviewId; } public Long getProductId(){ return productId; }
  public Long getMemberId(){ return memberId; } public int getRating(){ return rating; }
}
EOF
)"

# -------- domain:shared
wraw "$proj/domain/shared/build.gradle" "$(cat <<'EOF'
dependencies {
  implementation 'org.springframework.boot:spring-boot-starter-web'
  implementation 'org.springframework.boot:spring-boot-starter-security'
}
EOF
)"
wraw "$proj/domain/shared/src/main/java/ashen/store/shared/SecurityConfig.java" "$(cat <<'EOF'
package ashen.store.shared;

import org.springframework.context.annotation.*; import org.springframework.security.crypto.bcrypt.*; import org.springframework.security.crypto.password.PasswordEncoder;

@Configuration
public class SecurityConfig {
  @Bean public PasswordEncoder passwordEncoder(){ return new BCryptPasswordEncoder(); }
}
EOF
)"
wraw "$proj/domain/shared/src/main/java/ashen/store/shared/IdempotencyFilter.java" "$(cat <<'EOF'
package ashen.store.shared;

import jakarta.servlet.*; import jakarta.servlet.http.*; import org.springframework.stereotype.Component;
import java.io.IOException; import java.time.Instant; import java.util.Map; import java.util.concurrent.ConcurrentHashMap;

@Component
public class IdempotencyFilter implements Filter {
  private final Map<String, Instant> keyStore = new ConcurrentHashMap<>();
  public void doFilter(ServletRequest req, ServletResponse res, FilterChain chain) throws IOException, ServletException {
    if (req instanceof HttpServletRequest r) {
      String key = r.getHeader("Idempotency-Key");
      if (key!=null && !key.isEmpty()) keyStore.putIfAbsent(key, Instant.now());
    }
    chain.doFilter(req, res);
  }
}
EOF
)"
wraw "$proj/domain/shared/src/main/java/ashen/store/shared/CorrelationIdFilter.java" "$(cat <<'EOF'
package ashen.store.shared;

import jakarta.servlet.*; import jakarta.servlet.http.*; import org.springframework.stereotype.Component;
import java.io.IOException; import java.util.UUID;

@Component
public class CorrelationIdFilter implements Filter {
  public static final String HDR = "X-Correlation-ID";
  public void doFilter(ServletRequest req, ServletResponse res, FilterChain chain) throws IOException, ServletException {
    if (req instanceof HttpServletRequest r) {
      String id = r.getHeader(HDR);
      if (id==null || id.isEmpty()) { /* could add to response */ }
    }
    chain.doFilter(req, res);
  }
}
EOF
)"
wraw "$proj/domain/shared/src/main/java/ashen/store/shared/GlobalExceptionHandler.java" "$(cat <<'EOF'
package ashen.store.shared;

import org.springframework.http.*; import org.springframework.web.bind.annotation.*;

@ControllerAdvice
public class GlobalExceptionHandler {
  @ExceptionHandler(IllegalArgumentException.class)
  public ProblemDetail bad(IllegalArgumentException ex){
    var p = ProblemDetail.forStatusAndDetail(HttpStatus.BAD_REQUEST, ex.getMessage()); p.setTitle("Invalid Request"); return p;
  }
  @ExceptionHandler(Exception.class)
  public ProblemDetail gen(Exception ex){
    var p = ProblemDetail.forStatusAndDetail(HttpStatus.INTERNAL_SERVER_ERROR, "Internal error"); p.setTitle("Internal Server Error"); return p;
  }
}
EOF
)"
wraw "$proj/domain/shared/src/main/java/ashen/store/shared/package-info.java" "@org.springframework.modulith.ApplicationModule(name=\"shared\")\npackage ashen.store.shared;\n"

# -------- common:event
wraw "$proj/common/event/build.gradle" "dependencies { /* annotation only */ }\n"
wraw "$proj/common/event/src/main/java/ashen/store/event/Topic.java" "$(cat <<'EOF'
package ashen.store.event;

import java.lang.annotation.*;

@Retention(RetentionPolicy.RUNTIME)
@Target(ElementType.TYPE)
@Documented
public @interface Topic { String value(); }
EOF
)"

# -------- common:data-serializer
wraw "$proj/common/data-serializer/build.gradle" "dependencies { implementation 'com.fasterxml.jackson.core:jackson-databind'; implementation 'com.fasterxml.jackson.datatype:jackson-datatype-jsr310' }\n"
wraw "$proj/common/data-serializer/src/main/java/ashen/store/serializer/DataSerializer.java" "$(cat <<'EOF'
package ashen.store.serializer;

import com.fasterxml.jackson.databind.*; import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule;

public class DataSerializer {
  private static final ObjectMapper M;
  static { M = new ObjectMapper(); M.registerModule(new JavaTimeModule()); M.disable(SerializationFeature.WRITE_DATES_AS_TIMESTAMPS); }
  public static String serialize(Object o){ try { return M.writeValueAsString(o); } catch(Exception e){ throw new RuntimeException(e); } }
  public static <T> T deserialize(String json, Class<T> t){ try { return M.readValue(json, t); } catch(Exception e){ throw new RuntimeException(e); } }
}
EOF
)"

# -------- common:outbox-message-relay
wraw "$proj/common/outbox-message-relay/build.gradle" "$(cat <<'EOF'
dependencies {
  implementation 'org.springframework.boot:spring-boot-starter-data-jpa'
  implementation 'org.springframework.kafka:spring-kafka'
  implementation project(':common:data-serializer')
  implementation project(':common:event')
}
EOF
)"
wraw "$proj/common/outbox-message-relay/src/main/java/ashen/store/outbox/Outbox.java" "$(cat <<'EOF'
package ashen.store.outbox;

import jakarta.persistence.*; import java.time.Instant; import ashen.store.serializer.DataSerializer;

@Entity @Table(name="outbox")
public class Outbox {
  @Id @GeneratedValue(strategy=GenerationType.IDENTITY) private Long id;
  private String typeFqcn; @Lob private String payloadJson; private Instant createdAt = Instant.now();
  protected Outbox(){}
  public Outbox(Object payload){ this.typeFqcn=payload.getClass().getName(); this.payloadJson=DataSerializer.serialize(payload); }
  public Long getId(){ return id; } public String getTypeFqcn(){ return typeFqcn; } public String getPayloadJson(){ return payloadJson; }
}
EOF
)"
wraw "$proj/common/outbox-message-relay/src/main/java/ashen/store/outbox/OutboxRepository.java" "package ashen.store.outbox;\nimport org.springframework.data.jpa.repository.*; import java.util.*;\npublic interface OutboxRepository extends JpaRepository<Outbox,Long>{ List<Outbox> findByOrderByCreatedAtAsc(); }\n"
wraw "$proj/common/outbox-message-relay/src/main/java/ashen/store/outbox/OutboxRelayService.java" "$(cat <<'EOF'
package ashen.store.outbox;

import org.springframework.kafka.core.KafkaTemplate; import org.springframework.scheduling.annotation.Scheduled; import org.springframework.stereotype.Component;
import java.util.*; import java.util.concurrent.TimeUnit; import ashen.store.event.Topic;

@Component
public class OutboxRelayService {
  private final OutboxRepository repo; private final KafkaTemplate<String,String> kafka;
  public OutboxRelayService(OutboxRepository r, KafkaTemplate<String,String> k){ this.repo=r; this.kafka=k; }

  @Scheduled(fixedDelay=5000)
  public void relay(){
    List<Outbox> events = repo.findByOrderByCreatedAtAsc();
    for (Outbox o: events){
      try{
        Class<?> clz = Class.forName(o.getTypeFqcn());
        Topic t = clz.getAnnotation(Topic.class);
        String topic = (t!=null? t.value() : "default-topic");
        kafka.send(topic, o.getPayloadJson()).get(1, TimeUnit.SECONDS);
        repo.delete(o);
      } catch(Exception e){
        // TODO: DLQ persist; for now just keep it for retry on next run
      }
    }
  }
}
EOF
)"

# -------- common:snowflake
wraw "$proj/common/snowflake/build.gradle" "dependencies { /* none */ }\n"
wraw "$proj/common/snowflake/src/main/java/ashen/store/snowflake/SnowflakeIdGenerator.java" "$(cat <<'EOF'
package ashen.store.snowflake;

import org.springframework.stereotype.Component;

@Component
public class SnowflakeIdGenerator {
  private final long nodeId = 1L; private long seq=0L; private long last=-1L;
  public synchronized long nextId(){
    long now = System.currentTimeMillis();
    if (now==last){ seq=(seq+1)&0xFFF; if (seq==0) while((now=System.currentTimeMillis())==last){} }
    else seq=0;
    last=now;
    return (now<<22) | (nodeId<<12) | seq;
  }
}
EOF
)"

echo "[*] Done. You can now import the project and run with profile 'monolith'."
