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
                .status(req.getStatus() != null
                        ? Payment.StatusEnum.valueOf(req.getStatus().name())
                        : Payment.StatusEnum.PENDING)
                .createdAt(OffsetDateTime.now());
        if (req.getAmount() != null && req.getAmount() > 1_000_000) {
            p.setStatus(Payment.StatusEnum.FAILED);
            return ResponseEntity.ok(p);
        }
        return ResponseEntity.ok(p);
    }

    @Override
    public ResponseEntity<List<Payment>> listPayments() {
        return ResponseEntity.ok(List.of());
    }

    @Override
    public ResponseEntity<Payment> getPayment(UUID paymentId) {
        Payment p = new Payment()
                .id(paymentId)
                .amount(1999)
                .currency("EUR")
                .status(Payment.StatusEnum.AUTHORIZED)
                .createdAt(OffsetDateTime.now());
        return ResponseEntity.ok(p);
    }
}
