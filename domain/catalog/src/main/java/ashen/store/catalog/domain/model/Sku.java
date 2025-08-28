package ashen.store.catalog.domain.model;

import ashen.store.catalog.domain.value.Price;
import ashen.store.catalog.persistence.SkuOptionConverter;
import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.ToString;

import java.time.LocalDateTime;
import java.util.Map;

@Entity
@Table(name = "sku")
@Getter
@ToString
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class Sku {
    @Id
    private Long skuId;
    @Column(nullable=false)
    private Long productId;
    @Embedded
    private Price price;
    // DB엔 VARCHAR 하나, 코드에선 Map
    @Convert(converter = SkuOptionConverter.class)
    @Column(name="options", nullable=false, length=512)
    private Map<String, String> options = Map.of();
    @Column(nullable=false)
    private String skuCode;
    @Column(nullable=false)
    private boolean active = true;
    @Column(nullable=false, updatable = false)
    private LocalDateTime createdAt;
    @Column(nullable=false)
    private LocalDateTime modifiedAt;

    public static Sku create(Long skuId, Long productId, Price price, Map<String, String> options, String skuCode) {
        if (skuId == null || productId == null || price == null || skuCode == null || skuCode.isBlank()) {
            throw new IllegalArgumentException("skuId and productId and price are required");
        }
        Sku sku = new Sku();
        sku.skuId = skuId;
        sku.productId = productId;
        sku.price = price;
        sku.options = options == null ? Map.of(): options;
        sku.skuCode = skuCode;
        sku.active = true;
        sku.createdAt = LocalDateTime.now();
        sku.modifiedAt = sku.createdAt;
        return sku;
    }

    public void update(Price price, Map<String, String> options, Boolean active){
        if(price != null) this.price = price;
        if(options != null) this.options = options;
        if(active != null) this.active = active;
        this.modifiedAt = LocalDateTime.now();
    }
}
