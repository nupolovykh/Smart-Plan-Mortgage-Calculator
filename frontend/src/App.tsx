import React, { useEffect, useState, useCallback, useMemo } from 'react';
import './App.css';

interface Area {
  id: number;
  price: number;
  promo_id: number | null;
  address?: string;
}

interface Promo {
  id: number;
  discount_value: number;
  discount_type: string;
}

interface PaymentMethod {
  id: number;
  estimated_rate: number;
  bank_name?: string;
  logo?: string;
}

interface RequestEntity {
  id?: number;
  payment_method_id: number;
  maternal_capital: number;
  monthly_payment: number;
  initial_payment: number;
  mortgage_term: number;
  realty_id: number;
  promo_id: number | null;
  price: number;
  created_at?: string;
}

const App: React.FC = () => {
  const [areas, setAreas] = useState<Area[]>([]);
  const [promos, setPromos] = useState<Promo[]>([]);
  const [paymentMethods, setPaymentMethods] = useState<PaymentMethod[]>([]);
  const [requestsList, setRequestsList] = useState<RequestEntity[]>([]);

  const [selectedArea, setSelectedArea] = useState<Area | null>(null);
  const [selectedPaymentMethod, setSelectedPaymentMethod] = useState<PaymentMethod | null>(null);
  const [initialPayment, setInitialPayment] = useState<number>(0);
  const [maternalCapital, setMaternalCapital] = useState<number>(0);
  const [mortgageTerm, setMortgageTerm] = useState<number>(10);

  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const [successMessage, setSuccessMessage] = useState<string | null>(null);
  const [activeTab, setActiveTab] = useState<'calculator' | 'requests'>('calculator');
  const [isLoading, setIsLoading] = useState<boolean>(true);
  const [isSubmitting, setIsSubmitting] = useState<boolean>(false);

  // Use relative URL (Vite proxy forwards /api/* to PHP backend)
  const API_BASE = '';

  const calculatePrice = useCallback((area: Area, allPromos: Promo[]) => {
    let price = area.price;
    if (area.promo_id) {
      const promo = allPromos.find(p => p.id === area.promo_id);
      if (promo) {
        if (promo.discount_type === '%') {
          price = price * (1 - promo.discount_value / 100);
        } else if (promo.discount_type === 'rub') {
          price = Math.max(0, price - promo.discount_value);
        }
      }
    }
    return price;
  }, []);

  const calculateMonthlyPaymentValue = useCallback((
    currentCalculatedPrice: number,
    currentInitialPayment: number,
    currentMaternalCapital: number,
    currentMortgageTerm: number,
    currentSelectedPaymentMethod: PaymentMethod | null
  ) => {
    if (!currentSelectedPaymentMethod) return 0;

    const loanAmount = currentCalculatedPrice - currentInitialPayment - currentMaternalCapital;
    if (loanAmount <= 0) {
      return 0;
    }

    const annualRate = currentSelectedPaymentMethod.estimated_rate;
    const months = currentMortgageTerm * 12;

    if (annualRate === 0) {
      return parseFloat((loanAmount / months).toFixed(2));
    }

    const monthlyRate = annualRate / 12 / 100;
    const pow = Math.pow(1 + monthlyRate, months);
    const payment = loanAmount * (monthlyRate * pow) / (pow - 1);
    return parseFloat(payment.toFixed(2));
  }, []);

  const fetchRequestsList = useCallback(async () => {
    try {
      const response = await fetch(`${API_BASE}/api/requests`);
      const data: RequestEntity[] = await response.json();
      setRequestsList(data);
    } catch (error) {
      console.error('Error fetching requests list:', error);
    }
  }, []);

  useEffect(() => {
    let isMounted = true;

    (async () => {
      try {
        // Fetch everything in parallel
        const [areasRes, promosRes, paymentMethodsRes, requestsRes] = await Promise.all([
          fetch(`${API_BASE}/api/areas`),
          fetch(`${API_BASE}/api/promos`),
          fetch(`${API_BASE}/api/payment_methods`),
          fetch(`${API_BASE}/api/requests`),
        ]);

        const [areasData, promosData, paymentMethodsData, requestsData] = await Promise.all([
          areasRes.json(),
          promosRes.json(),
          paymentMethodsRes.json(),
          requestsRes.json(),
        ]);

        if (!isMounted) return;

        setAreas(areasData);
        setPromos(promosData);
        setPaymentMethods(paymentMethodsData);
        setRequestsList(requestsData);

        // Only set defaults if nothing selected yet
        setSelectedArea(prev => prev ?? (areasData.length > 0 ? areasData[0] : null));
        setSelectedPaymentMethod(prev => prev ?? (paymentMethodsData.length > 0 ? paymentMethodsData[0] : null));
      } catch (error) {
        console.error('Error fetching initial data:', error);
        if (!isMounted) return;
        setErrorMessage('Failed to fetch initial database tables.');
      } finally {
        if (isMounted) setIsLoading(false);
      }
    })();

    return () => {
      isMounted = false;
    };
  }, []); // run once on mount

  const calculatedPrice = useMemo(() => {
    return selectedArea ? calculatePrice(selectedArea, promos) : 0;
  }, [selectedArea, promos, calculatePrice]);

  const monthlyPayment = useMemo(() => {
    return calculateMonthlyPaymentValue(
      calculatedPrice,
      initialPayment,
      maternalCapital,
      mortgageTerm,
      selectedPaymentMethod
    );
  }, [calculatedPrice, initialPayment, maternalCapital, mortgageTerm, selectedPaymentMethod, calculateMonthlyPaymentValue]);

  const handleSubmit = async () => {
    if (!selectedArea || !selectedPaymentMethod) {
      setErrorMessage('Please select an area and a payment method.');
      return;
    }

    setErrorMessage(null);
    setSuccessMessage(null);

    const requestData = {
      payment_method_id: selectedPaymentMethod.id,
      maternal_capital: maternalCapital,
      monthly_payment: monthlyPayment,
      initial_payment: initialPayment,
      mortgage_term: mortgageTerm,
      realty_id: selectedArea.id,
      promo_id: selectedArea.promo_id,
      price: calculatedPrice,
    };

    try {
      setIsSubmitting(true);
      const response = await fetch(`${API_BASE}/api/integrations/sendForm`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(requestData),
      });

      const result = await response.json();

      if (response.ok) {
        setSuccessMessage(result.message);
        fetchRequestsList(); // Refresh list immediately
      } else {
        setErrorMessage(result.message || 'An error occurred during submission.');
      }
    } catch (error) {
      setErrorMessage('Failed to connect to the API server.');
      console.error('Submission error:', error);
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <div className="container">
      <div className="header">
        <h1>Smart Plan Mortgage Center</h1>
        <div className="tabs">
          <button 
            className={`tab-btn ${activeTab === 'calculator' ? 'active' : ''}`}
            onClick={() => setActiveTab('calculator')}
          >
            🏡 Mortgage Calculator
          </button>
          <button 
            className={`tab-btn ${activeTab === 'requests' ? 'active' : ''}`}
            onClick={() => {
              setActiveTab('requests');
              fetchRequestsList();
            }}
          >
            📊 Requests History
          </button>
        </div>
      </div>

      {errorMessage && <div className="error-message">{errorMessage}</div>}
      {successMessage && <div className="success-message">{successMessage}</div>}

      {isLoading ? (
        <div className="loading-container">
          <div className="loading-spinner"></div>
          <p className="loading-text">Loading mortgage data...</p>
        </div>
      ) : activeTab === 'calculator' ? (
        <div className="calculator-layout">
          <div className="card left-panel">
            <h2>Select Your Plot & Method</h2>

            <div className="form-group">
              <label>Select Plot/Realty</label>
              <select 
                onChange={(e) => {
                  const id = parseInt(e.target.value);
                  const found = areas.find(a => a.id === id) || null;
                  setSelectedArea(found);
                  setInitialPayment(0);
                  setMaternalCapital(0);
                }} 
                value={selectedArea?.id || ''}
              >
                {areas.map(area => {
                  const p = promos.find(pr => pr.id === area.promo_id);
                  const promoText = p ? ` [Discount: -${p.discount_value}${p.discount_type}]` : '';
                  return (
                    <option key={area.id} value={area.id}>
                      Plot №{area.id} (Base: {area.price.toLocaleString()} RUB){promoText}
                    </option>
                  );
                })}
              </select>
              {selectedArea?.address && (
                <div className="address-display">
                  📍 <strong>Address:</strong> {selectedArea.address}
                </div>
              )}
            </div>

            <div className="form-group">
              <label>Select Payment Method</label>
              <div className="payment-methods-selector">
                {paymentMethods.map(pm => (
                  <div 
                    key={pm.id} 
                    className={`payment-method-card ${selectedPaymentMethod?.id === pm.id ? 'selected' : ''}`}
                    onClick={() => setSelectedPaymentMethod(pm)}
                  >
                    {pm.logo && <img src={pm.logo} alt={pm.bank_name} className="bank-logo" onError={(e) => { e.currentTarget.style.display = 'none'; }} />}
                    <div className="bank-info">
                      <div className="bank-name">{pm.bank_name || `Bank ID ${pm.id}`}</div>
                      <div className="bank-rate">Rate: {pm.estimated_rate}%</div>
                    </div>
                  </div>
                ))}
              </div>
            </div>

            <div className="form-group">
              <label>Initial Payment: {initialPayment.toLocaleString()} RUB</label>
              <input
                type="range"
                min="0"
                max={selectedArea ? Math.floor(calculatedPrice * 0.9) : 0}
                step="5000"
                value={initialPayment}
                onChange={(e) => setInitialPayment(parseFloat(e.target.value))}
              />
              <div className="range-limits">
                <span>0 RUB</span>
                <span>Max (90%): {selectedArea ? Math.floor(calculatedPrice * 0.9).toLocaleString() : 0} RUB</span>
              </div>
            </div>

            <div className="form-group">
              <label>Use Maternal Capital: {maternalCapital.toLocaleString()} RUB</label>
              <input
                type="range"
                min="0"
                max="800000"
                step="10000"
                value={maternalCapital}
                onChange={(e) => setMaternalCapital(parseFloat(e.target.value))}
              />
              <div className="range-limits">
                <span>0 RUB</span>
                <span>800,000 RUB</span>
              </div>
            </div>

            <div className="form-group">
              <label>Mortgage Term: {mortgageTerm} years</label>
              <input
                type="range"
                min="1"
                max="30"
                step="1"
                value={mortgageTerm}
                onChange={(e) => setMortgageTerm(parseInt(e.target.value))}
              />
              <div className="range-limits">
                <span>1 year</span>
                <span>30 years</span>
              </div>
            </div>
          </div>

          <div className="card right-panel">
            <h2>Calculation Result</h2>
            <div className="results-box">
              <div className="result-item">
                <span>Plot Original Price:</span>
                <span className="strike-through">{selectedArea ? `${selectedArea.price.toLocaleString()} RUB` : '-'}</span>
              </div>
              <div className="result-item highlighted">
                <span>Price with Promo:</span>
                <span className="price-big">{calculatedPrice.toLocaleString()} RUB</span>
              </div>
              <div className="result-item">
                <span>Total Down Payment:</span>
                <span>{(initialPayment + maternalCapital).toLocaleString()} RUB</span>
              </div>
              <div className="result-item">
                <span>Total Credit Loan:</span>
                <span>{Math.max(0, calculatedPrice - initialPayment - maternalCapital).toLocaleString()} RUB</span>
              </div>
              <div className="result-item highlighted-rate">
                <span>Selected Bank & Rate:</span>
                <span>{selectedPaymentMethod ? `${selectedPaymentMethod.bank_name || 'Bank'} (${selectedPaymentMethod.estimated_rate}%)` : '-'}</span>
              </div>
              <div className="result-item final-payment">
                <span>Monthly Payment:</span>
                <span className="payment-big">{monthlyPayment.toLocaleString()} RUB / mo</span>
              </div>
            </div>
            <button className="submit-btn" onClick={handleSubmit} disabled={isSubmitting}>
              {isSubmitting ? '⏳ Submitting...' : '🚀 Submit Application to DB'}
            </button>
          </div>
        </div>
      ) : (
        <div className="requests-panel card">
          <h2>Application Requests History (Saved in SQLite DB)</h2>
          <div className="table-responsive">
            <table>
              <thead>
                <tr>
                  <th>ID</th>
                  <th>Plot (Realty ID)</th>
                  <th>Plot Price (With Promo)</th>
                  <th>Maternal Capital</th>
                  <th>Down Payment (Added MC)</th>
                  <th>Term</th>
                  <th>Monthly Payment</th>
                  <th>Payment Method</th>
                  <th>Created At</th>
                </tr>
              </thead>
              <tbody>
                {requestsList.length === 0 ? (
                  <tr>
                    <td colSpan={9} style={{ textAlign: 'center', padding: '20px' }}>
                      No applications submitted yet.
                    </td>
                  </tr>
                ) : (
                  requestsList.map((req) => {
                    const bank = paymentMethods.find(pm => pm.id === req.payment_method_id);
                    return (
                      <tr key={req.id}>
                        <td><strong>#{req.id}</strong></td>
                        <td>Plot №{req.realty_id}</td>
                        <td>{req.price.toLocaleString()} RUB</td>
                        <td>{req.maternal_capital.toLocaleString()} RUB</td>
                        <td>{req.initial_payment.toLocaleString()} RUB</td>
                        <td>{req.mortgage_term} yrs</td>
                        <td className="payment-column">{req.monthly_payment.toLocaleString()} RUB</td>
                        <td>{bank ? bank.bank_name : `Method #${req.payment_method_id}`}</td>
                        <td>{req.created_at}</td>
                      </tr>
                    );
                  })
                )}
              </tbody>
            </table>
          </div>
        </div>
      )}
    </div>
  );
};

export default App;
