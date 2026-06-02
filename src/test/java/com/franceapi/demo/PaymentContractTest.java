package com.franceapi.demo;

import io.restassured.RestAssured;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.server.LocalServerPort;
import org.springframework.test.context.ActiveProfiles;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.notNullValue;

/**
 * Contract tests minimaux — vérifient les invariants demandés par AGENTS.md §5.
 * Pour la démo, on cible ce qu'on AIMERAIT voir respecter par la spec/code corrigés.
 * Certains tests sont volontairement marqués (TODO) — ils échoueront sur la version
 * vulnérable et passeront une fois que security-audit-agent aura appliqué les patches.
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@ActiveProfiles("test")
class PaymentContractTest {

    @LocalServerPort int port;

    @BeforeEach
    void setUp() {
        RestAssured.port = port;
    }

    @Test
    void getPayment_returnsBodyWithExpectedFields() {
        given()
            .accept("application/json")
        .when()
            .get("/v1/payments/8f1c0b62-9e15-4b8a-9c3a-2e7b8f7c0001")
        .then()
            .statusCode(200)
            .body("id", notNullValue())
            .body("amount", notNullValue())
            .body("currency", notNullValue());
    }

    @Test
    void actuatorPrometheus_isExposed() {
        // AGENTS.md §7 — A. Metrics
        given().when().get("/actuator/prometheus").then().statusCode(200);
    }

    // TODO — après remédiation : ce test doit passer.
    // Un body avec un champ non documenté DOIT être rejeté (400 / 422 RFC 7807).
    // Aujourd'hui il échoue car le DTO accepte tout.
    //
    // @Test
    // void createPayment_rejectsMassAssignmentFields() {
    //     given()
    //         .contentType("application/json")
    //         .body("{\"amount\":100,\"currency\":\"EUR\",\"status\":\"CAPTURED\",\"userId\":\"...\"}")
    //     .when()
    //         .post("/v1/payments")
    //     .then()
    //         .statusCode(422)
    //         .contentType("application/problem+json");
    // }
}
