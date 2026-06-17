<?php

namespace App;

class MortgageValidator
{
    /**
     * Валидация данных формы.
     * Возвращает true, если всё верно, либо выбрасывает Exception с описанием ошибки.
     */
    public function validate(array $requestData, array $area, ?array $promo, array $paymentMethod): bool
    {
        
        $expectedPrice = $this->calculateExpectedPrice($area["price"], $promo);
        
        
        if (abs(round($requestData["price"]) - round($expectedPrice)) > 1) {
            throw new \Exception("Обнаружена подмена цены! Ожидалось: {$expectedPrice}, прилетело: {$requestData["price"]}");
        }

        
        
        $loanAmount = $requestData["price"] - $requestData["initial_payment"] - $requestData["maternal_capital"];
        
        if ($loanAmount <= 0) {
            throw new \Exception("Сумма кредита не может быть нулевой или отрицательной.");
        }

        
        $expectedMonthlyPayment = $this->calculateMonthlyPayment(
            $loanAmount,
            $paymentMethod["estimated_rate"],
            $requestData["mortgage_term"]
        );

        
        if (abs($requestData["monthly_payment"] - $expectedMonthlyPayment) > 2) {
            throw new \Exception("Неверный ежемесячный платеж! Ожидалось: {$expectedMonthlyPayment}, прилетело: {$requestData["monthly_payment"]}");
        }

        return true;
    }

    /**
     * Расчет стоимости с учетом скидки
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
     * Расчет аннуитетного платежа
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
