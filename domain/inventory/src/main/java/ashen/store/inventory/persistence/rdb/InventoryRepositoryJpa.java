package ashen.store.inventory.persistence.rdb;
import ashen.store.inventory.domain.*;
import org.springframework.data.jpa.repository.*;
import java.util.*;
public interface InventoryRepositoryJpa extends InventoryRepository, JpaRepository<Inventory,Long>{
    Optional<Inventory> findByProductId(Long productId);
}
