<?php

if (file_exists(__DIR__ . '/../vendor/autoload.php')) {
    require_once __DIR__ . '/../vendor/autoload.php';
}
require_once __DIR__ . '/MortgageValidator.php';

use App\MortgageValidator;

// CORS Headers for React Frontend
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

header('Content-Type: application/json');

try {
    $db = new PDO('sqlite:' . __DIR__ . '/../database.sqlite');
    $db->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(['status' => 'error', 'message' => 'Database connection failed: ' . $e->getMessage()]);
    exit();
}

$requestUri = $_SERVER['REQUEST_URI'] ?? '';
$requestMethod = $_SERVER['REQUEST_METHOD'] ?? 'GET';

// Parse query string if any
$parsedUrl = parse_url($requestUri);
$path = $parsedUrl['path'] ?? '';

// Basic Router
if ($requestMethod === 'GET') {
    if (strpos($path, 'api/areas') !== false) {
        $stmt = $db->query('SELECT * FROM areas');
        $areas = $stmt->fetchAll(PDO::FETCH_ASSOC);
        echo json_encode($areas);
        exit();
    } elseif (strpos($path, 'api/promos') !== false) {
        $stmt = $db->query('SELECT * FROM promos');
        $promos = $stmt->fetchAll(PDO::FETCH_ASSOC);
        echo json_encode($promos);
        exit();
    } elseif (strpos($path, 'api/payment_methods') !== false) {
        $stmt = $db->query('SELECT * FROM payment_methods');
        $paymentMethods = $stmt->fetchAll(PDO::FETCH_ASSOC);
        echo json_encode($paymentMethods);
        exit();
    } elseif (strpos($path, 'api/requests') !== false) {
        $stmt = $db->query('SELECT * FROM requests ORDER BY id DESC');
        $requests = $stmt->fetchAll(PDO::FETCH_ASSOC);
        echo json_encode($requests);
        exit();
    }
}

if ($requestMethod === 'POST' && strpos($path, 'api/integrations/sendForm') !== false) {
    // Get JSON input
    $input = file_get_contents('php://input');
    $requestData = json_decode($input, true);

    if (json_last_error() !== JSON_ERROR_NONE) {
        http_response_code(400);
        echo json_encode(['status' => 'error', 'message' => 'Invalid JSON input.']);
        exit();
    }

    // Validate required fields
    $requiredFields = ['payment_method_id', 'maternal_capital', 'monthly_payment', 'initial_payment', 'mortgage_term', 'realty_id', 'price'];
    foreach ($requiredFields as $field) {
        if (!isset($requestData[$field])) {
            http_response_code(400);
            echo json_encode(['status' => 'error', 'message' => 'Missing required field: ' . $field]);
            exit();
        }
    }
    // Make promo_id optional/nullable
    if (!array_key_exists('promo_id', $requestData)) {
        $requestData['promo_id'] = null;
    }

    $stmt = $db->prepare('SELECT * FROM areas WHERE id = :id');
    $stmt->execute([':id' => $requestData['realty_id']]);
    $area = $stmt->fetch(PDO::FETCH_ASSOC);

    $promo = null;
    $promoId = $area['promo_id'] ?? $requestData['promo_id'];
    if ($promoId) {
        $stmt = $db->prepare('SELECT * FROM promos WHERE id = :id');
        $stmt->execute([':id' => $promoId]);
        $promo = $stmt->fetch(PDO::FETCH_ASSOC);
    }

    $stmt = $db->prepare('SELECT * FROM payment_methods WHERE id = :id');
    $stmt->execute([':id' => $requestData['payment_method_id']]);
    $paymentMethod = $stmt->fetch(PDO::FETCH_ASSOC);

    if (!$area) {
        http_response_code(404);
        echo json_encode(['status' => 'error', 'message' => 'Area not found.']);
        exit();
    }

    if ($promoId && !$promo) {
        http_response_code(404);
        echo json_encode(['status' => 'error', 'message' => 'Promo not found.']);
        exit();
    }

    if (!$paymentMethod) {
        http_response_code(404);
        echo json_encode(['status' => 'error', 'message' => 'Payment method not found.']);
        exit();
    }

    $validator = new MortgageValidator();

    try {
        $isValid = $validator->validate($requestData, $area, $promo, $paymentMethod);

        if ($isValid) {
            $stmt = $db->prepare(
                'INSERT INTO requests (payment_method_id, maternal_capital, monthly_payment, initial_payment, mortgage_term, realty_id, promo_id, price)
                 VALUES (:payment_method_id, :maternal_capital, :monthly_payment, :initial_payment, :mortgage_term, :realty_id, :promo_id, :price)'
            );
            $stmt->execute([
                ':payment_method_id' => $requestData['payment_method_id'],
                ':maternal_capital' => $requestData['maternal_capital'],
                ':monthly_payment' => $requestData['monthly_payment'],
                ':initial_payment' => $requestData['initial_payment'] + $requestData['maternal_capital'],
                ':mortgage_term' => $requestData['mortgage_term'],
                ':realty_id' => $requestData['realty_id'],
                ':promo_id' => $requestData['promo_id'] ?? null,
                ':price' => $requestData['price']
            ]);

            $requestData['initial_payment'] += $requestData['maternal_capital'];
            http_response_code(201);
            echo json_encode(['status' => 'success', 'message' => 'Request entity created successfully.', 'data' => $requestData]);
            exit();
        }
    } catch (Exception $e) {
        http_response_code(400);
        echo json_encode(['status' => 'error', 'message' => $e->getMessage()]);
        exit();
    }
}

// Fallback response for unhandled endpoints
http_response_code(404);
echo json_encode(['status' => 'error', 'message' => 'Endpoint not found: ' . $path]);
