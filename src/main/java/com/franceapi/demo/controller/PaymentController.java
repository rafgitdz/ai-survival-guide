package com.franceapi.demo.controller;

import com.franceapi.demo.dto.Payment;
import com.franceapi.demo.dto.PaymentCreateRequest;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;

/**
 * VOLONTAIREMENT IMPARFAIT — sert aux use cases SECURE et AUDIT.
 *
 * Défauts plantés :
 *  - POST renvoie 200 sur "insufficient funds" au lieu de 422 + application/problem+json.
 *  - GET /v1/payments/{id} sans contrôle d'autorisation (BOLA, API1).
 *  - Le DTO Payment expose internalAccountId qui n'est pas dans la spec (API3).
 *  - Pas de pagination sur GET /v1/payments (API4).
 */
@RestController
@RequestMapping("/v1/payments")
public class PaymentController {

    @PostMapping(consumes = MediaType.APPLICATION_JSON_VALUE)
    public ResponseEntity<Payment> create(@RequestBody PaymentCreateRequest req) {
        // PLANTÉ : trust input — mass assignment réel
        Payment p = new Payment();
        p.id = UUID.randomUUID();
        p.amount = req.amount;
        p.currency = req.currency;
        p.status = req.status != null ? req.status : "PENDING";       // PLANTÉ
        p.internalAccountId = req.internalAccountId;                   // PLANTÉ
        p.createdAt = OffsetDateTime.now();

        // PLANTÉ : "insufficient funds" → 200 OK avec status FAILED
        if (req.amount != null && req.amount > 1_000_000) {
            p.status = "FAILED";
            return ResponseEntity.ok(p);
        }
        return ResponseEntity.ok(p);
    }

    @GetMapping
    public List<Payment> list() {
        // PLANTÉ : pas de pagination
        return List.of();
    }

    @GetMapping("/{paymentId}")
    public Payment get(@PathVariable UUID paymentId) {
        // PLANTÉ : aucun check que le paymentId appartient bien à l'utilisateur courant (BOLA).
        Payment p = new Payment();
        p.id = paymentId;
        p.amount = 1999;
        p.currency = "EUR";
        p.status = "AUTHORIZED";
        p.internalAccountId = "acct_internal_42";  // leak
        p.createdAt = OffsetDateTime.now();
        return p;
    }
}
