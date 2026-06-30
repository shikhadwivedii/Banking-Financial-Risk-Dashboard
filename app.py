import streamlit as st
import pandas as pd
# ... (your other imports like model_builder, plotly, etc.)

# --- THE GATEKEEPER START ---
def check_password():
    st.sidebar.title("Login")
    user_pass = st.sidebar.text_input("Enter Password", type="password")
    if user_pass == st.secrets["APP_PASSWORD"]:
        return True
    else:
        st.sidebar.error("Incorrect password")
        return False

if not check_password():
    st.stop() # This stops the rest of the code from running
# --- THE GATEKEEPER END ---

# NOW, YOUR DASHBOARD CODE STARTS BELOW THIS LINE
st.title("Banking Financial Risk Dashboard")
# ... (your existing code for data loading, charts, etc.)


import streamlit as st
import pandas as pd
import plotly.express as px
from sklearn.linear_model import LogisticRegression

# 1. Page Config
st.set_page_config(page_title="Bank Analytics Dashboard", layout="wide")
st.title("🏦 Banking Financial & Risk Dashboard")

# 2. Load Data
@st.cache_data
def load_data():
    loan_df = pd.read_csv('loan_data.csv')
    trans_df = pd.read_csv('trans_data.zip')
    return loan_df, trans_df

loan_df, trans_df = load_data()

# 3. Sidebar Navigation
menu = st.sidebar.selectbox("Select Analysis", [
    "Portfolio Overview", 
    "Predictive Risk", 
    "Operational Efficiency", 
    "Loan Maturity Analysis"
])

if menu == "Portfolio Overview":
    st.header("📊 Loan Portfolio Overview")
    
    col1, col2, col3 = st.columns(3)
    col1.metric("Total Volume", f"${loan_df['amount'].sum():,.0f}")
    col2.metric("Total Loans", len(loan_df))
    default_count = len(loan_df[loan_df['status'].isin(['D', 'C'])])
    col3.metric("Defaulted Loans", default_count)
    
    st.markdown("---")
    
    c1, c2 = st.columns(2)
    with c1:
        fig_hist = px.histogram(loan_df, x="amount", nbins=20, title="Distribution of Loan Amounts")
        st.plotly_chart(fig_hist, use_container_width=True)
    with c2:
        fig_pie = px.pie(loan_df, names='status', title="Loan Status Composition")
        st.plotly_chart(fig_pie, use_container_width=True)
        
    st.subheader("Duration Analysis")
    fig_bar = px.box(loan_df, x="status", y="duration", title="Loan Duration vs. Status")
    st.plotly_chart(fig_bar, use_container_width=True)

elif menu == "Predictive Risk":
    st.header("Logistic Regression Risk Prediction")
    amt = st.slider("Loan Amount", 1000, 100000, step=1000)
    duration = st.slider("Loan Duration (Months)", 12, 60, step=6)
    payments = st.slider("Monthly Payment", 100, 5000, step=100)
    
    X = loan_df[['amount', 'duration', 'payments']]
    y = loan_df['status'].isin(['C', 'D']).astype(int)
    
    model = LogisticRegression()
    model.fit(X, y)
    
    user_data = pd.DataFrame({'amount': [amt], 'duration': [duration], 'payments': [payments]})
    prediction = model.predict(user_data)
    
    if prediction[0] == 1:
        st.error("Prediction: High Risk (Potential Default)")
    else:
        st.success("Prediction: Low Risk (Likely to Repay)")

# ---OPERATIONAL EFFICIENCY ---
elif menu == "Operational Efficiency":
    st.header("⚙️ Transaction Velocity Analysis")
    # This assumes trans_df exists and has 'account_id'
    trans_counts = trans_df.groupby('account_id')['trans_id'].count()
    fig = px.histogram(trans_counts, x="trans_id", title="Number of Transactions per Account")
    st.plotly_chart(fig, use_container_width=True)
    st.write(f"Average transactions per account: {trans_counts.mean():.2f}")

# ---Loan Maturity Analysis ---
elif menu == "Loan Maturity Analysis":
    st.header("⏳ Loan Maturity & Repayment Trends")
    
    # We will look at how loan duration impacts the risk status
    # This uses existing columns: 'duration', 'status', 'amount'
    
    fig = px.scatter(loan_df, x="duration", y="amount", color="status", 
                     title="Loan Amount vs. Duration (Colored by Status)",
                     hover_data=['status'])
    st.plotly_chart(fig, use_container_width=True)
    
    st.markdown("""
    **Insight:**
    * This scatter plot helps identify if 'Defaulted' loans (C or D) cluster in 
      specific duration or amount ranges.
    * Use this to see if the bank should tighten requirements for long-term loans.
    """)

import streamlit as st
from model_builder import train_model

# --- ADD THIS TO THE VERY BOTTOM OF app.py ---
from model_builder import train_model # Keep this at the top with your other imports

st.sidebar.markdown("---")
if st.sidebar.button("Run Predictive Analysis"):
    # This keeps the UI clean until the user specifically asks for it
    model, scaler, auc = train_model(df)
    st.sidebar.write(f"Model AUC: {auc:.2f}")
    st.sidebar.success("Model trained successfully!")