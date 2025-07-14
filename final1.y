### do not make the graph for the  


import os
import pandas as pd
import numpy as np
import matplotlib as mlt
import streamlit as st
from dotenv import load_dotenv
from groq import Groq
import io
import contextlib

# Load API key from .env
load_dotenv()
GROQ_API_KEY = os.getenv("GROQ_API_KEY")

# Initialize Groq client
client = Groq(api_key=GROQ_API_KEY)

# Streamlit UI
st.set_page_config(page_title="Excel Chatbot 2 ", layout="wide")
st.title("📊 Excel/CSV Chatbot")

# 📢 Prompt instructions for user
st.markdown("""
### 📊 **Excel Chatbot Prompt (User-Facing)**

Upload any Excel file (`.xlsx`, `.xls`, or `.csv`) and ask your question about the data.  
The chatbot will automatically:

✅ Analyze the uploaded file and extract the column names.  
✅ Pass your question along with the relevant column context to a language model.  
✅ Generate and execute Python code to answer your query using your data.

**Just upload your file and ask questions like:**
- “What is the average salary by department?”
- “Show me the top 5 highest selling products.”
- “Filter rows where age > 30 and city is 'New York'.”
""")

# Upload file
uploaded_file = st.file_uploader("📂 Upload your Excel, XLS, or CSV file", type=["csv", "xlsx", "xls"])

if uploaded_file:
    # Load data
    filename = uploaded_file.name.lower()
    try:
        if filename.endswith('.csv'):
            df = pd.read_csv(uploaded_file)
        else:
            df = pd.read_excel(uploaded_file)
    except Exception as e:
        st.error(f"❌ Could not read file: {e}")
        st.stop()

    # Show preview
    st.subheader("🔍 Data Preview")
    st.dataframe(df.head())

    # Show columns
    st.write("**🧩 Columns detected:**", list(df.columns))

    # User question
    user_query = st.text_input("💬 Ask a question about the data:")

    if user_query:
        with st.spinner("🤖 Thinking..."):
            # Build prompt for LLM
            prompt = f"""
You are a Python data expert.
Available DataFrame columns: {list(df.columns)}

Write Python code to answer this question from the DataFrame `df`:
Question: "{user_query}"

⚠️ IMPORTANT RULES:
1. Only return Python code (no explanations or markdown)
2. Always store your final result in a variable named `result`
3. Use ONLY these imports: pandas as pd, numpy as np
4. Your code must work directly on the `df` variable
5. Handle missing values appropriately
6. If showing data, limit to 100 rows maximum
"""

            try:
                # Get response from Groq API
                response = client.chat.completions.create(
                    model="llama3-8b-8192",
                    messages=[
                        {"role": "system", "content": "You are an expert Python data assistant."},
                        {"role": "user", "content": prompt}
                    ],
                    temperature=0.2
                )
                generated_code = response.choices[0].message.content.strip()
                
                # Clean code output (remove markdown code fences)
                if generated_code.startswith('```python'):
                    generated_code = generated_code[9:-3].strip()
                elif generated_code.startswith('```'):
                    generated_code = generated_code[3:-3].strip()
                
                st.subheader("🧠 Generated Code")
                st.code(generated_code, language='python')

                # Prepare execution environment
                env = {
                    'df': df.copy(),  # Use copy to prevent original modification
                    'pd': pd,
                    'np': np
                }
                
                # Capture stdout for print statements
                output_capture = io.StringIO()
                
                try:
                    with contextlib.redirect_stdout(output_capture):
                        exec(generated_code, env)
                except Exception as e:
                    st.error(f"🚨 Code execution error: {str(e)}")
                    st.stop()

                # Get captured output and result
                captured_output = output_capture.getvalue()
                result = env.get('result', None)
                
                st.subheader("✅ Results")
                
                # Display captured output if exists
                if captured_output:
                    st.write("**📝 Console Output:**")
                    st.code(captured_output)
                
                # Display result based on its type
                if result is not None:
                    if isinstance(result, pd.DataFrame):
                        if len(result) > 100:
                            st.warning(f"⚠️ Showing first 100 rows of {len(result)} total rows")
                        st.dataframe(result.head(100))
                    elif isinstance(result, pd.Series):
                        st.dataframe(result.to_frame())
                    elif isinstance(result, (int, float, str)):
                        st.metric("Result", result)
                    else:
                        st.write(result)
                else:
                    st.info("💡 Code executed successfully but no 'result' variable was created")
                
            except Exception as e:
                st.error(f"❌ Error generating response: {e}")
