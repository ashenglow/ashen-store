package ashen.store.order.persistence.rdb;
import ashen.store.order.domain.*;
import org.springframework.data.jpa.repository.*;
import java.util.*; import java.util.UUID;
public interface OrderRepositoryJpa extends OrderRepository, JpaRepository<Order,UUID>{
    Optional<Order> findByIdempotencyKey(String idempotencyKey);}
