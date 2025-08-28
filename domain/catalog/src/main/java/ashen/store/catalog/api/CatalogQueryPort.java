package ashen.store.catalog.api;

import java.util.Map;

public interface CatalogQueryPort {
    SkuPriceView getSkuPriceByCode(Long merchantId, String skuCode);
    SkuPriceView getSkuPriceByProductAndOptions(Long productId, Map<String,String> options);

    record SkuPriceView(Long listPrice, Long salePrice, Long effectivePrice, String currency) {}
}
