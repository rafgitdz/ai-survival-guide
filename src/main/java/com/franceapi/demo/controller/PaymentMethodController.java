package com.franceapi.demo.controller;

import com.franceapi.demo.generated.api.PaymentMethodsApi;
import com.franceapi.demo.generated.dto.PaymentMethod;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

/**
 * Stub: the spec declares the `paymentMethods` tag, so the generator creates
 * the PaymentMethodsApi interface, which must be implemented for the project
 * to compile.
 */
@RestController
public class PaymentMethodController implements PaymentMethodsApi {

    @Override
    public ResponseEntity<List<PaymentMethod>> listPaymentMethods() {
        return ResponseEntity.ok(List.of());
    }
}
