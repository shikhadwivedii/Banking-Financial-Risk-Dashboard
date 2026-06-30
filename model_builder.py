import pandas as pd
from sklearn.model_selection import train_test_split
from sklearn.linear_model import LogisticRegression
from sklearn.preprocessing import StandardScaler
from sklearn.metrics import roc_auc_score

def train_model(data):
    # 1. Feature Engineering & Binary Conversion
    # We turn the 'status' column into 1 (Default) or 0 (Not Default)
    # Adjust 'D' if your column uses a different letter/number for defaults
    data['binary_status'] = data['status'].apply(lambda x: 1 if x == 'D' else 0)
    
    X = data[['amount', 'duration', 'payments']] 
    y = data['binary_status']
    
    # 2. Split
    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)
    
    # 3. Scaling
    scaler = StandardScaler()
    X_train_scaled = scaler.fit_transform(X_train)
    X_test_scaled = scaler.transform(X_test)
    
    # 4. Model
    model = LogisticRegression()
    model.fit(X_train_scaled, y_train)
    
    # 5. Evaluation
    # Now that y is binary, this will work perfectly!
    auc = roc_auc_score(y_test, model.predict_proba(X_test_scaled)[:, 1])
    
    return model, scaler, auc