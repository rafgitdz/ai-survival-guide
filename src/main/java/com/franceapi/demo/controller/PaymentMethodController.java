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
 *
 * The `/v1/paymentMethods` path (camelCase) stays planted in the spec: it
 * violates AGENTS.md §2 (kebab-case) and the audits must report it.
 */
@RestController
public class PaymentMethodController implements PaymentMethodsApi {

    @Override
    public ResponseEntity<List<PaymentMethod>> listPaymentMethods() {
        return ResponseEntity.ok(List.of());
    }
}
