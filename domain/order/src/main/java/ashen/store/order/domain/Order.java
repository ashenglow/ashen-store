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
