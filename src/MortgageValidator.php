<?php

namespace App;

class MortgageValidator
{
    /**
     * Validate form data.
     * Returns true if data is valid, or throws Exception with error details.
     */
    public function validate(array $requestData, array $area, ?array $promo, array $paymentMethod): bool
    {
        
        $expectedPrice = $this->calculateExpectedPrice($area["price"], $promo);
        
        
        if (abs(round($requestData["price"]) - round($expectedPrice)) > 1) {
            throw new \Exception("Price tampering detected! Expected: {$expectedPrice}, received: {$requestData["price"]}");
        }

        
        
        $loanAmount = $requestData["price"] - $requestData["initial_payment"] - $requestData["maternal_capital"];
        
        if ($loanAmount <= 0) {
            throw new \Exception("Loan amount must be greater than zero.");
        }

        
        $expectedMonthlyPayment = $this->calculateMonthlyPayment(
            $loanAmount,
            $paymentMethod["estimated_rate"],
            $requestData["mortgage_term"]
        );

        
        if (abs($requestData["monthly_payment"] - $expectedMonthlyPayment) > 2) {
            throw new \Exception("Incorrect monthly payment! Expected: {$expectedMonthlyPayment}, received: {$requestData["monthly_payment"]}");
        }

        return true;
    }

    /**
     * Calculate expected price with discount
     */
    public function calculateExpectedPrice(float $basePrice, ?array $promo): float
    {
        if (!$promo) {
            return $basePrice;
        }

        if ($promo["discount_type"] === "%") {
            return $basePrice * (1 - $promo["discount_value"] / 100);
        } 
        
        if ($promo["discount_type"] === "rub") {
            return max(0.0, $basePrice - $promo["discount_value"]);
        }

        return $basePrice;
    }

    /**
     * Calculate annuity payment
     */
    public function calculateMonthlyPayment(float $loanAmount, float $annualRate, int $years): float
    {
        $months = $years * 12;
        
        
        if ($annualRate == 0) {
            return round($loanAmount / $months, 2);
        }

        
        $monthlyRate = $annualRate / 12 / 100;

        
        $pow = pow(1 + $monthlyRate, $months);
        $payment = $loanAmount * ($monthlyRate * $pow) / ($pow - 1);

        return round($payment, 2);
    }
}
