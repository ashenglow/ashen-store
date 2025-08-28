package ashen.store.catalog.api;

import ashen.store.catalog.domain.model.Category;

import java.math.BigDecimal;
import java.util.List;
import java.util.Map;

public interface CatalogCommandPort {
    ProductId registerProduct(RegisterProductCommand cmd);   // 상품 + 초기 SKU(1개 이상)

    void updateProduct(UpdateProductCommand cmd);            // 상품 메타/활성

    void updateSku(UpdateSkuCommand cmd);                    // 가격/옵션/활성/코드(선택)

    // ===== Value types / DTOs =====
    record ProductId(Long value) {}
    record SkuId(Long value) {}

    record SkuDraft(
            Map<String,String> options,   // 빈맵/NULL -> DEFAULT
            Long listPrice,
            Long salePrice,
            String currency,
            String skuCode                // null -> 시스템 생성
    ) {}

    // ===== Commands =====
    record RegisterProductCommand(
            Long merchantId,
            String korName,
            String engName,
            Category category,
            BigDecimal abv,
            List<SkuDraft> initialSkus // 단일 상품 1개, 옵션상품 2개+
    ) {}

    record UpdateProductCommand(
            Long productId,
            String korName,
            String engName,
            Category category,
            BigDecimal abv,
            Boolean active
    ) {}

    record UpdateSkuCommand(
            Long skuId,
            Map<String,String> options,   // 옵션 변경 허용(null이면 유지)
            Long listPrice,
            Long salePrice,
            String currency,
            Boolean active,
            String skuCode               // (선택) 코드 변경 시
    ) {}
}