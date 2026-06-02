package com.franceapi.demo.dto;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;

/**
 * VOLONTAIREMENT VULNÉRABLE — sert au use case SECURE.
 *
 * Défauts plantés (à révéler par owasp-reviewer / security-audit-agent) :
 *  - Le DTO expose `status`, `userId`, `internalAccountId` → API3 mass assignment.
 *  - Aucun @JsonIgnoreProperties(ignoreUnknown=false) → le client peut injecter
 *    n'importe quel champ.
 */
public class PaymentCreateRequest {
    @NotNull
    public Integer amount;

    @NotNull
    @Pattern(regexp = "^[A-Z]{3}$")
    public String currency;

    // PLANTÉ — ne devrait jamais être accepté en input.
    public String status;
    public String userId;
    public String internalAccountId;
}
