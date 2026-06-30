<?php

if (file_exists(__DIR__ . '/../vendor/autoload.php')) {
    require_once __DIR__ . '/../vendor/autoload.php';
}
require_once __DIR__ . '/MortgageValidator.php';

use App\MortgageValidator;

// ────────────────────────────────────────────────
// Environment Configuration (.env support)
// ────────────────────────────────────────────────
$envFile = __DIR__ . '/../.env';
$env = [];
if (file_exists($envFile)) {
    $lines = file($envFile, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
    foreach ($lines as $line) {
        $line = trim($line);
        if ($line === '' || str_starts_with($line, '#')) {
            continue;
        }
        if (str_contains($line, '=')) {
            [$key, $value] = explode('=', $line, 2);
            $key = trim($key);
            $value = trim($value);
            $env[$key] = $value;
            // Also set as environment variable for getenv() access
            putenv("$key=$value");
        }
    }
}

// Helper to get config value with fallback
$config = function (string $key, $default = null) use ($env) {
    return $env[$key] ?? getenv($key) ?: $default;
};

// ────────────────────────────────────────────────
// CORS Headers
// ────────────────────────────────────────────────
$allowedOrigins = $config('CORS_ALLOWED_ORIGINS', '*');
if ($allowedOrigins === '*') {
    header('Access-Control-Allow-Origin: *');
} else {
    $origin = $_SERVER['HTTP_ORIGIN'] ?? '';
    $origins = array_map('trim', explode(',', $allowedOrigins));
    if (in_array($origin, $origins, true)) {
        header("Access-Control-Allow-Origin: $origin");
    } else {
        header('Access-Control-Allow-Origin: ' . $origins[0]);
    }
}
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

header('Content-Type: application/json');

// ────────────────────────────────────────────────
// Database Connection
// ────────────────────────────────────────────────
$dbPath = $config('DB_PATH', __DIR__ . '/../database.sqlite');
try {
    $db = new PDO('sqlite:' . $dbPath);
    $db->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    // Enable foreign keys
    $db->exec('PRAGMA foreign_keys = ON');
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

    // Strip whitespace from string fields
    foreach ($requestData as $key => $value) {
        if (is_string($value)) {
            $requestData[$key] = trim($value);
        }
    }

    // Add numeric range validation for all numeric fields
    $numericFields = [
        'price' => ['min' => 0, 'allow_zero' => false],
        'initial_payment' => ['min' => 0, 'allow_zero' => true],
        'maternal_capital' => ['min' => 0, 'allow_zero' => true],
        'monthly_payment' => ['min' => 0, 'allow_zero' => false],
        'payment_method_id' => ['min' => 0, 'allow_zero' => false, 'is_int' => true],
        'realty_id' => ['min' => 0, 'allow_zero' => false, 'is_int' => true],
        'mortgage_term' => ['min' => 1, 'max' => 50, 'is_int' => true]
    ];

    foreach ($numericFields as $field => $rules) {
        $val = $requestData[$field];
        if (!is_numeric($val)) {
            http_response_code(400);
            echo json_encode(['status' => 'error', 'message' => "Field '$field' must be numeric."]);
            exit();
        }
        
        $numVal = $rules['is_int'] ?? false ? (int)$val : (float)$val;
        
        if (($rules['is_int'] ?? false) && (string)$numVal !== (string)$val && (float)$val !== (float)$numVal) {
            http_response_code(400);
            echo json_encode(['status' => 'error', 'message' => "Field '$field' must be an integer."]);
            exit();
        }

        if (isset($rules['max']) && $numVal > $rules['max']) {
            http_response_code(400);
            echo json_encode(['status' => 'error', 'message' => "Field '$field' must not be greater than {$rules['max']}."]);
            exit();
        }

        if (isset($rules['min'])) {
            if ($rules['allow_zero'] ?? false) {
                if ($numVal < $rules['min']) {
                    http_response_code(400);
                    echo json_encode(['status' => 'error', 'message' => "Field '$field' must be greater than or equal to {$rules['min']}."]);
                    exit();
                }
            } else {
                if ($numVal <= $rules['min']) {
                    http_response_code(400);
                    echo json_encode(['status' => 'error', 'message' => "Field '$field' must be greater than {$rules['min']}."]);
                    exit();
                }
            }
        }
        
        // Cast requestData value to proper type
        $requestData[$field] = $numVal;
    }

    // Validate promo_id is either null or positive integer
    if ($requestData['promo_id'] !== null) {
        $promoId = $requestData['promo_id'];
        if (!is_numeric($promoId) || (int)$promoId <= 0 || (int)$promoId != $promoId) {
            http_response_code(400);
            echo json_encode(['status' => 'error', 'message' => "Field 'promo_id' must be null or a positive integer."]);
            exit();
        }
        $requestData['promo_id'] = (int)$promoId;
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
