package com.franceapi.demo.controller;

import com.franceapi.demo.generated.api.PaymentsApi;
import com.franceapi.demo.generated.dto.Payment;
import com.franceapi.demo.generated.dto.PaymentCreateRequest;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.RestController;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;

/**
 * Implements the PaymentsApi interface GENERATED from openapi/payments.yaml.
 *
 * If the spec changes (rename, removal, new required field), this class stops
 * compiling until it is aligned. That is the core of hard contract-first.
 *
 * DELIBERATELY VULNERABLE, for the SECURE and AUDIT use cases.
 * Planted defects that survive code generation:
 *  - POST returns 200 on "insufficient funds" instead of 422 + Problem (see spec).
 *  - GET /v1/payments/{id}: no authorization check (BOLA, API1).
 *  - listPayments: no pagination (API4).
 *  - The generated PaymentCreateRequest DTO contains `status`, `userId` and
 *    `internalAccountId` because the SPEC exposes them: mass assignment
 *    propagated from the contract to the code. That is the point: a
 *    vulnerable contract produces vulnerable code. The fix belongs in the spec.
 *
 * NOTE: the `internalAccountId` leak in the RESPONSE is gone, because the
 * generator never creates a field missing from the Payment schema.
 * Contract-first mechanically kills this kind of drift.
 */
@RestController
public class PaymentController implements PaymentsApi {

    @Override
    public ResponseEntity<Payment> createPayment(PaymentCreateRequest req) {
        Payment p = new Payment()
                .id(UUID.randomUUID())
                .amount(req.getAmount())
                .currency(req.getCurrency())
                // PLANTED: trusts client input
                .status(req.getStatus() != null
                        ? Payment.StatusEnum.valueOf(req.getStatus().name())
                        : Payment.StatusEnum.PENDING)
                .createdAt(OffsetDateTime.now());

        // PLANTED: 200 OK even on the "insufficient funds" business error
        if (req.getAmount() != null && req.getAmount() > 1_000_000) {
            p.setStatus(Payment.StatusEnum.FAILED);
            return ResponseEntity.ok(p);
        }
        return ResponseEntity.ok(p);
    }

    @Override
    public ResponseEntity<List<Payment>> listPayments() {
        // PLANTED: no pagination (API4 Unrestricted Resource Consumption)
        return ResponseEntity.ok(List.of());
    }

    @Override
    public ResponseEntity<Payment> getPayment(UUID paymentId) {
        // PLANTED: no ownership check (BOLA, API1).
        // PLANTED: security: [] in the spec, so a sensitive endpoint is exposed without auth (API2).
        Payment p = new Payment()
                .id(paymentId)
                .amount(1999)
                .currency("EUR")
                .status(Payment.StatusEnum.AUTHORIZED)
                .createdAt(OffsetDateTime.now());
        return ResponseEntity.ok(p);
    }
}
