package ashen.store.catalog.service;

import ashen.store.catalog.api.CatalogCommandPort;
import ashen.store.catalog.api.CatalogQueryPort;
import ashen.store.catalog.domain.model.Product;
import ashen.store.catalog.domain.model.Sku;
import ashen.store.catalog.domain.value.Price;
import ashen.store.catalog.persistence.ProductRepository;
import ashen.store.catalog.persistence.SkuOptionConverter;
import ashen.store.catalog.persistence.SkuRepository;
import ashen.store.snowflake.SnowflakeIdGenerator;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.Map;

@Service
@RequiredArgsConstructor
public class CatalogService implements CatalogCommandPort, CatalogQueryPort {
    private final SnowflakeIdGenerator snowflake;
    private final ProductRepository productRepository;
    private final SkuRepository skuRepository;

    @Transactional
    @Override
    public ProductId registerProduct(RegisterProductCommand cmd) {
        if (cmd.initialSkus() == null || cmd.initialSkus().isEmpty()){
            throw new IllegalStateException("No initial skus");
        }
        var pid = snowflake.nextId();
        Product product = productRepository.save(
                Product.create(
                        pid,
                        cmd.merchantId(),
                        cmd.korName(),
                        cmd.engName(),
                        cmd.category(),
                        cmd.abv()
                )
        );

        long seq = 1;
        for (var skuDraft : cmd.initialSkus()) {
            var price = Price.of(skuDraft.listPrice(), skuDraft.salePrice(), skuDraft.currency());
            var options = skuDraft.options();
            var code = (skuDraft.skuCode() != null && !skuDraft.skuCode().isBlank()) ?
                    skuDraft.skuCode() : genSkuCode(pid, seq++);

            if (skuRepository.existsByProductIdAndOptions(pid, options)) {
                throw new IllegalStateException("Duplicate Options: " + options);
            }
            if(skuRepository.existsByProductIdAndSkuCode(pid, code)) {
                throw new IllegalStateException("Duplicate SkuCode: " + code);
            }
            var sid = snowflake.nextId();
           skuRepository.save(
                        Sku.create(
                                sid,
                                pid,
                                price,
                               options,
                                code
                        )
                );
        }
        return new ProductId(pid);
    }

    private String genSkuCode(long pid, long seq) {
        return "P" + Long.toString(pid, 36).toUpperCase() + "-" + Long.toString(seq, 36).toUpperCase();
    }

    @Transactional
    @Override
    public void updateProduct(UpdateProductCommand cmd) {
        var p = productRepository.findById(
                cmd.productId()
        ).orElseThrow(() -> new IllegalStateException("Product not found"));
        p.update(cmd.korName(), cmd.engName(), cmd.category(), cmd.abv(), cmd.active());
    }

    @Transactional
    @Override
    public void updateSku(UpdateSkuCommand cmd) {
        var sku = skuRepository.findById(cmd.skuId()).orElseThrow(() -> new IllegalStateException("Sku not found"));

        var price = Price.of(
                cmd.listPrice() != null ? cmd.listPrice() : sku.getPrice().getListPrice(),
                cmd.salePrice() != null ? cmd.salePrice() : sku.getPrice().getSalePrice(),
                cmd.currency() != null ? cmd.currency() : sku.getPrice().getCurrency()
        );

        // option 변경 시 정규키 중복 검사
        if (cmd.options() != null){
            var newKey = SkuOptionConverter.toKey(cmd.options());
            var oldKey = SkuOptionConverter.toKey(sku.getOptions());
            if(!newKey.equals(oldKey) &&
            skuRepository.existsByProductIdAndOptions(sku.getProductId(), cmd.options())) {
                throw new IllegalStateException("Duplicate Option set: " + newKey);
            }
            sku.update(price, cmd.options(), cmd.active());
        } else {
            sku.update(price, null, cmd.active());
        }


    }

    @Transactional(readOnly = true)
    @Override
    public SkuPriceView getSkuPriceByCode(Long merchantId, String skuCode) {
        var sku = skuRepository.findByMerchantAndSkuCode(merchantId, skuCode)
                .orElseThrow(() -> new IllegalStateException("Sku not found"));
        var price = sku.getPrice();
        return new SkuPriceView(price.getListPrice(), price.getSalePrice(), price.effective(), price.getCurrency());
    }

    @Transactional(readOnly = true)
    @Override
    public SkuPriceView getSkuPriceByProductAndOptions(Long productId, Map<String, String> options) {
        var sku = skuRepository.findTopByProductIdAndOptions(productId, options)
                .orElseThrow(() -> new IllegalStateException("Sku not found"));
        var price = sku.getPrice();
        return new SkuPriceView(price.getListPrice(), price.getSalePrice(), price.effective(), price.getCurrency());
    }
}
