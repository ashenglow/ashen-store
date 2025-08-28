package ashen.store.inventory.domain;
import java.util.*;
public interface InventoryRepository{
    Optional<Inventory> findByProductId(Long productId);
    Inventory save(Inventory inv);}
