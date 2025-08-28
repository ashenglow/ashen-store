package ashen.store.catalog.domain.model;

import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.ToString;

import java.math.BigDecimal;
import java.time.LocalDateTime;

@Entity
@Table(name="product")
@Getter
@ToString
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class Product {
  @Id
  private Long productId;
  @Column(nullable=false)
  private Long merchantId;
  @Column(nullable=false)
  private String korName;
  @Column(nullable=false)
  private String engName;
  @Column(nullable=false)
  @Enumerated(EnumType.STRING)
  private Category category;
  @Column(precision = 5, scale = 2)
  private BigDecimal abv;
  @Column(nullable=false)
  private boolean active = true;
  @Column(nullable=false, updatable = false)
  private LocalDateTime createdAt;
  @Column(nullable=false)
  private LocalDateTime modifiedAt;

  public static Product create(Long productId, Long merchantId, String korName, String engName, Category category, BigDecimal abv) {
    Product product = new Product();
    product.productId = productId;
    product.merchantId = merchantId;
    product.korName = korName;
    product.engName = engName;
    product.category = category;
    product.abv = abv;
    product.active = true;
    product.createdAt = LocalDateTime.now();
    product.modifiedAt = product.createdAt;
    return product;
  }

  public void update(String korName, String engName, Category category, BigDecimal abv, Boolean active) {
    if(korName != null) this.korName = korName;
    if(engName != null) this.engName = engName;
    if(category != null) this.category = category;
    if(abv != null) this.abv = abv;
    if(active != null) this.active = active;
    this.modifiedAt = LocalDateTime.now();
  }

}
