package ashen.store.catalog.domain;

import ashen.store.ModulithTestApplication;
import ashen.store.catalog.api.CatalogCommandPort;
import ashen.store.catalog.domain.model.Category;
import ashen.store.catalog.persistence.ProductRepository;
import ashen.store.catalog.persistence.SkuRepository;
import ashen.store.snowflake.SnowflakeIdGenerator;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.context.annotation.Import;
import org.springframework.modulith.test.ApplicationModuleTest;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.util.List;
import java.util.Map;
import java.util.Objects;

import static org.assertj.core.api.AssertionsForClassTypes.assertThat;
import static org.mockito.BDDMockito.given;

@ApplicationModuleTest
@Import(ModulithTestApplication.class)
class CatalogModuleTest {

    @MockBean SnowflakeIdGenerator snowflake;

    @Autowired CatalogCommandPort catalog;
    @Autowired ProductRepository productRepo;
    @Autowired SkuRepository skuRepo;

    @Test
    @Transactional
    void register_updates_jpa_ok() {
        given(snowflake.nextId()).willReturn(1000L, 2000L);

        var cmd = new CatalogCommandPort.RegisterProductCommand(
                10L, "니카 위스키", "Nikka Whisky", Category.WHISKY, new BigDecimal("40.0"),
                List.of(new CatalogCommandPort.SkuDraft(Map.of("bottle_size","700ml"), 50_000L, 45_000L, "KRW", null))
        );
        var pid = catalog.registerProduct(cmd);

        assertThat(pid.value()).isEqualTo(1000L);
        assertThat(productRepo.findById(1000L)).isPresent();
        assertThat(skuRepo.findById(2000L)).isPresent();

        var p = productRepo.findById(1000L).orElseThrow();
        System.out.printf("\n[Product] id=%d, merchant=%d, ko=%s, en=%s, cat=%s, abv=%s, active=%s%n",
                p.getProductId(), p.getMerchantId(), p.getKorName(), p.getEngName(),
                p.getCategory(), Objects.toString(p.getAbv(), "null"), p.isActive());

        var s = skuRepo.findById(2000L).orElseThrow();
        System.out.printf("[SKU] id=%d, product=%d, code=%s, options=%s, list=%d, sale=%s, cur=%s, active=%s%n%n",
                s.getSkuId(), s.getProductId(), s.getSkuCode(), s.getOptions(),
                s.getPrice().getListPrice(), Objects.toString(s.getPrice().getSalePrice(), "null"),
                s.getPrice().getCurrency(), s.isActive());
    }
}
