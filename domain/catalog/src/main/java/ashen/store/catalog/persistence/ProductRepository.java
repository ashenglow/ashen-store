package ashen.store.catalog.persistence;

import ashen.store.catalog.domain.model.Product;
import org.springframework.data.jpa.repository.JpaRepository;

public interface ProductRepository extends JpaRepository<Product, Long> {
    boolean existsByProductIdAndActiveTrue(Long productId);
}
