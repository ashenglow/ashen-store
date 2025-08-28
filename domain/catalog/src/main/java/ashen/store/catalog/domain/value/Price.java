package ashen.store.catalog.domain.value;

import jakarta.persistence.Embeddable;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;

@Embeddable
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class Price {
    private Long listPrice;
    private Long salePrice;
    private String currency;

    private Price(Long listPrice, Long salePrice, String currency) {
        this.listPrice = listPrice;
        this.salePrice = salePrice;
        this.currency = currency;
    }

    public static Price of(Long listPrice, Long salePrice, String currency) {
        if ( listPrice == null || listPrice < 0) {
            throw new IllegalArgumentException("listPrice must be greater than zero");
        }
        if(salePrice != null && salePrice < 0) {
            throw new IllegalArgumentException("salePrice must be greater than zero");
        }
        if(currency == null || currency.isBlank()) {
            currency = "KRW";
        }
        return new Price(listPrice, salePrice, currency);
    }

    public long effective(){
        return salePrice != null ? salePrice : listPrice;
    }
}
