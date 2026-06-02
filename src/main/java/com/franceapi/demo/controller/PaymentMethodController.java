package com.franceapi.demo.controller;

import com.franceapi.demo.generated.api.PaymentMethodsApi;
import com.franceapi.demo.generated.dto.PaymentMethod;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

/**
 * Stub — la spec déclare la tag `paymentMethods`, donc le generator crée
 * l'interface PaymentMethodsApi. Il faut l'implémenter pour que le projet
 * compile.
 *
 * Le path `/v1/paymentMethods` (camelCase) reste planté dans la spec :
 * c'est une violation de AGENTS.md §2 (kebab-case) que les audits doivent
 * remonter.
 */
@RestController
public class PaymentMethodController implements PaymentMethodsApi {

    @Override
    public ResponseEntity<List<PaymentMethod>> listPaymentMethods() {
        return ResponseEntity.ok(List.of());
    }
}
