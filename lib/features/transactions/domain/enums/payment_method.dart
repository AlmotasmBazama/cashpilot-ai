// Compatibility facade for the former Transactions-owned payment-method
// contract. The declaration is owned by Payment Methods and re-exported here
// so existing imports, generated parts and public APIs keep the same type.
export '../../../payment_methods/domain/enums/payment_method.dart'
    show PaymentMethod, PaymentMethodMapper, PaymentMethodX;
