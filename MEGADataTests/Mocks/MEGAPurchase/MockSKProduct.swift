import StoreKit

final class MockSKProduct: SKProduct {
    convenience init(identifier: String, price: String, priceLocale: Locale) {
        self.init()
        self.setValue(identifier, forKey: "productIdentifier")
        self.setValue(price, forKey: "price")
        self.setValue(priceLocale, forKey: "priceLocale")
    }
}
