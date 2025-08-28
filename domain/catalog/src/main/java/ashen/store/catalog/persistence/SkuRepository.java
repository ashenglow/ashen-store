package ashen.store.catalog.persistence;

import ashen.store.catalog.domain.model.Sku;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.Map;
import java.util.Optional;

public interface SkuRepository extends JpaRepository<Sku, Long> {
    // (product_id, options) 존재 여부
    boolean existsByProductIdAndOptions(Long productId, Map<String,String> options);

    // 1건만 필요하면 Top
    Optional<Sku> findTopByProductIdAndOptions(Long productId, Map<String,String> options);


    boolean existsByProductIdAndSkuCode(Long productId, String skuCode);

    @Query("""
      select s from Sku s
        join Product p on p.productId = s.productId
       where p.merchantId = :merchantId and s.skuCode = :skuCode
    """)
    Optional<Sku> findByMerchantAndSkuCode(@Param("merchantId") Long merchantId, @Param("skuCode") String skuCode);

}
