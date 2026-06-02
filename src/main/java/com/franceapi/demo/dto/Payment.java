package com.franceapi.demo.dto;

import java.time.OffsetDateTime;
import java.util.UUID;

public class Payment {
    public UUID id;
    public Integer amount;
    public String currency;
    public String status;
    public OffsetDateTime createdAt;

    // PLANTÉ — ce champ est retourné par le controller mais ABSENT de la spec.
    // Démontre le mismatch spec/code détecté par openapi-consistency-auditor + owasp-reviewer (API3 leak).
    public String internalAccountId;
}
