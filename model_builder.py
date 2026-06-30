## Step 1: Prepare the "Model Script"
import pandas as pd
from sklearn.model_selection import train_test_split
from sklearn.linear_model import LogisticRegression
from sklearn.preprocessing import StandardScaler
from sklearn.metrics import accuracy_score, roc_auc_score

def train_model(data):
    # 1. Feature Engineering (Simplified)
    # Ensure you drop columns that aren't numeric/useful
    X = data[['amount', 'duration', 'payments']] 
    y = data['status'] # 0 for Good, 1 for Default
    
    # 2. Split
    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)
    
    # 3. Scaling (Crucial for Logistic Regression!)
    scaler = StandardScaler()
    X_train_scaled = scaler.fit_transform(X_train)
    X_test_scaled = scaler.transform(X_test)
    
    # 4. Model
    model = LogisticRegression()
    model.fit(X_train_scaled, y_train)
    
    # 5. Evaluation
    y_pred = model.predict(X_test_scaled)
    auc = roc_auc_score(y_test, model.predict_proba(X_test_scaled)[:, 1])
    
    return model, scaler, auc

