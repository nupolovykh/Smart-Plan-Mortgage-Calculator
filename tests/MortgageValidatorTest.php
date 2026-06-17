<?php

namespace Tests;

use App\MortgageValidator;
use PHPUnit\Framework\TestCase;

class MortgageValidatorTest extends TestCase
{
    private MortgageValidator $validator;

    protected function setUp(): void
    {
        parent::setUp();
        $this->validator = new MortgageValidator();
    }

    public function testCalculateExpectedPriceWithPercentagePromo(): void
    {
        $basePrice = 1000000.0;
        $promo = ["discount_value" => 10, "discount_type" => "%"];
        $expectedPrice = 900000.0; // 10% discount
        $this->assertEquals($expectedPrice, $this->validator->calculateExpectedPrice($basePrice, $promo));
    }

    public function testCalculateExpectedPriceWithAbsolutePromo(): void
    {
        $basePrice = 1000000.0;
        $promo = ["discount_value" => 50000, "discount_type" => "rub"];
        $expectedPrice = 950000.0; // 50000 rub discount
        $this->assertEquals($expectedPrice, $this->validator->calculateExpectedPrice($basePrice, $promo));
    }

    public function testCalculateExpectedPriceWithoutPromo(): void
    {
        $basePrice = 1500000.0;
        $promo = null;
        $expectedPrice = 1500000.0;
        $this->assertEquals($expectedPrice, $this->validator->calculateExpectedPrice($basePrice, $promo));
    }

    public function testCalculateMonthlyPayment(): void
    {
        // Example from a known calculator (e.g., https://calcus.ru/kreditnyy-kalkulyator)
        $loanAmount = 1000000.0;
        $annualRate = 10.0; // 10%
        $years = 5;
        $expectedPayment = 21247.04; // Rounded to 2 decimal places
        $this->assertEquals($expectedPayment, $this->validator->calculateMonthlyPayment($loanAmount, $annualRate, $years));

        $loanAmount = 2000000.0;
        $annualRate = 8.5; // 8.5%
        $years = 15;
        $expectedPayment = 19685.18;
        $this->assertEquals($expectedPayment, $this->validator->calculateMonthlyPayment($loanAmount, $annualRate, $years));
    }

    public function testCalculateMonthlyPaymentZeroRate(): void
    {
        $loanAmount = 120000.0;
        $annualRate = 0.0;
        $years = 10;
        $expectedPayment = 1000.0;
        $this->assertEquals($expectedPayment, $this->validator->calculateMonthlyPayment($loanAmount, $annualRate, $years));
    }

    public function testValidateSuccessful(): void
    {
        $requestData = [
            "payment_method_id" => 1,
            "maternal_capital" => 0,
            "monthly_payment" => 7970.30,
            "initial_payment" => 494910,
            "mortgage_term" => 25,
            "realty_id" => 42,
            "promo_id" => 7,
            "price" => 1484730.0, // Corrected price after 10% discount on 1649700
        ];
        $area = ["id" => 42, "price" => 1649700, "promo_id" => 7, "address" => "Test Address"];
        $promo = ["id" => 7, "discount_value" => 10, "discount_type" => "%"];
        $paymentMethod = ["id" => 1, "estimated_rate" => 8.5, "bank_name" => "Test Bank"];

        $this->assertTrue($this->validator->validate($requestData, $area, $promo, $paymentMethod));
    }

    public function testValidatePriceMismatch(): void
    {
        $requestData = [
            "payment_method_id" => 1,
            "maternal_capital" => 0,
            "monthly_payment" => 9325,
            "initial_payment" => 494910,
            "mortgage_term" => 25,
            "realty_id" => 42,
            "promo_id" => 7,
            "price" => 1600000, // Incorrect price
        ];
        $area = ["id" => 42, "price" => 1649700, "promo_id" => 7, "address" => "Test Address"];
        $promo = ["id" => 7, "discount_value" => 10, "discount_type" => "%"];
        $paymentMethod = ["id" => 1, "estimated_rate" => 8.5, "bank_name" => "Test Bank"];

        $this->expectException(\Exception::class);
        $this->expectExceptionMessage("Обнаружена подмена цены!");
        $this->validator->validate($requestData, $area, $promo, $paymentMethod);
    }

    public function testValidateLoanAmountTooLow(): void
    {
        $requestData = [
            "payment_method_id" => 1,
            "maternal_capital" => 0,
            "monthly_payment" => 0, // Should not trigger monthly payment mismatch if loan is <= 0
            "initial_payment" => 1623850, // Enough to make loan amount <= 0
            "mortgage_term" => 25,
            "realty_id" => 131,
            "promo_id" => null,
            "price" => 1623850.0,
        ];
        $area = ["id" => 131, "price" => 1623850, "promo_id" => null, "address" => "Test Address"];
        $promo = null;
        $paymentMethod = ["id" => 1, "estimated_rate" => 8.5, "bank_name" => "Test Bank"];

        $this->expectException(\Exception::class);
        $this->expectExceptionMessage("Сумма кредита не может быть нулевой или отрицательной.");
        $this->validator->validate($requestData, $area, $promo, $paymentMethod);
    }

    public function testValidateMonthlyPaymentMismatch(): void
    {
        $requestData = [
            "payment_method_id" => 1,
            "maternal_capital" => 0,
            "monthly_payment" => 5000, // Incorrect monthly payment
            "initial_payment" => 494910,
            "mortgage_term" => 25,
            "realty_id" => 42,
            "promo_id" => 7,
            "price" => 1484730.0,
        ];
        $area = ["id" => 42, "price" => 1649700, "promo_id" => 7, "address" => "Test Address"];
        $promo = ["id" => 7, "discount_value" => 10, "discount_type" => "%"];
        $paymentMethod = ["id" => 1, "estimated_rate" => 8.5, "bank_name" => "Test Bank"];

        $this->expectException(\Exception::class);
        $this->expectExceptionMessage("Неверный ежемесячный платеж!");
        $this->validator->validate($requestData, $area, $promo, $paymentMethod);
    }

    // Test case for promo_id being null in requestData
    public function testValidateWithNullPromoIdInRequest(): void
    {
        $requestData = [
            "payment_method_id" => 2,
            "maternal_capital" => 0,
            "monthly_payment" => 5353.56, 
            "initial_payment" => 494910,
            "mortgage_term" => 25,
            "realty_id" => 131,
            "promo_id" => null, // Explicitly null promo_id
            "price" => 1623850.0,
        ];
        $area = ["id" => 131, "price" => 1623850, "promo_id" => null, "address" => "Test Address"];
        $promo = null;
        $paymentMethod = ["id" => 2, "estimated_rate" => 3.0, "bank_name" => "Test Bank 2"];

        $this->assertTrue($this->validator->validate($requestData, $area, $promo, $paymentMethod));
    }

    // Test case for promo_id missing in requestData (should be handled by api.php setting it to null)
    public function testValidateWithMissingPromoIdInRequest(): void
    {
        $requestData = [
            "payment_method_id" => 2,
            "maternal_capital" => 0,
            "monthly_payment" => 5353.56, 
            "initial_payment" => 494910,
            "mortgage_term" => 25,
            "realty_id" => 131,
            // "promo_id" is missing
            "price" => 1623850.0,
        ];
        $area = ["id" => 131, "price" => 1623850, "promo_id" => null, "address" => "Test Address"];
        $promo = null; // Will be null as it\"s missing from requestData and area has no promo_id
        $paymentMethod = ["id" => 2, "estimated_rate" => 3.0, "bank_name" => "Test Bank 2"];

        // The validate method expects $promo to be ?array, so it should handle null
        // The `api.php` side ensures that if `promo_id` is missing, it\"s set to null before passing.
        $this->assertTrue($this->validator->validate($requestData, $area, $promo, $paymentMethod));
    }
}
