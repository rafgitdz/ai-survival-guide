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
 * Implémente l'interface PaymentsApi GÉNÉRÉE depuis openapi/payments.yaml.
 *
 * Si la spec change (renommage, suppression, nouveau champ obligatoire),
 * cette classe ne compile plus tant qu'on ne l'aligne pas. C'est le cœur
 * du contract-first dur.
 *
 * VOLONTAIREMENT VULNÉRABLE — pour les use cases SECURE et AUDIT.
 * Défauts plantés qui survivent à la génération :
 *  - POST renvoie 200 sur "insufficient funds" au lieu de 422 + Problem (cf. spec).
 *  - GET /v1/payments/{id} : aucun contrôle d'autorisation (BOLA, API1).
 *  - listPayments : pas de pagination (API4).
 *  - Le DTO PaymentCreateRequest généré contient `status`, `userId`,
 *    `internalAccountId` parce que la SPEC les expose → mass assignment
 *    propagé du contrat au code. C'est la démonstration : un contrat
 *    vulnérable produit un code vulnérable. Le fix se fait dans la spec.
 *
 * NOTE — le leak `internalAccountId` côté RESPONSE a disparu : le generator
 * ne crée pas un champ absent du schéma Payment. Le contract-first tue
 * mécaniquement ce type de drift.
 */
@RestController
public class PaymentController implements PaymentsApi {

    @Override
    public ResponseEntity<Payment> createPayment(PaymentCreateRequest req) {
        Payment p = new Payment()
                .id(UUID.randomUUID())
                .amount(req.getAmount())
                .currency(req.getCurrency())
                // PLANTÉ — trust input
                .status(req.getStatus() != null
                        ? Payment.StatusEnum.valueOf(req.getStatus().name())
                        : Payment.StatusEnum.PENDING)
                .createdAt(OffsetDateTime.now());

        // PLANTÉ — 200 OK même en cas d'erreur métier "insufficient funds"
        if (req.getAmount() != null && req.getAmount() > 1_000_000) {
            p.setStatus(Payment.StatusEnum.FAILED);
            return ResponseEntity.ok(p);
        }
        return ResponseEntity.ok(p);
    }

    @Override
    public ResponseEntity<List<Payment>> listPayments() {
        // PLANTÉ — pas de pagination (API4 Unrestricted Resource Consumption)
        return ResponseEntity.ok(List.of());
    }

    @Override
    public ResponseEntity<Payment> getPayment(UUID paymentId) {
        // PLANTÉ — aucun check d'ownership (BOLA, API1).
        // PLANTÉ — security: [] dans la spec → endpoint sensible exposé sans auth (API2).
        Payment p = new Payment()
                .id(paymentId)
                .amount(1999)
                .currency("EUR")
                .status(Payment.StatusEnum.AUTHORIZED)
                .createdAt(OffsetDateTime.now());
        return ResponseEntity.ok(p);
    }
}
