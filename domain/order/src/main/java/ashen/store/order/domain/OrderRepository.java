package ashen.store.order.domain;
import java.util.*;
import java.util.UUID;
public interface OrderRepository{
    Order save(Order o); Optional<Order> findByIdempotencyKey(String k);
}
