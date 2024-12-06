set -e
mkdir ./agents
cat <<EOF > requirements.txt
streamlit==1.37.0
langchain==0.1.16
langchain-openai==0.1.3
python-dotenv==1.0.1
EOF
cat <<EOF > ./agents/__init__.py
from .simple_openai_agent import SimpleOpenaiAgent
EOF
cat <<EOF > ./agents/base_agent.py
class BaseAgent(object):
    pass
EOF
cat <<EOF > ./agents/simple_openai_agent.py
from .base_agent import BaseAgent
from langchain_openai import ChatOpenAI
import os
from langchain_core.prompts import ChatPromptTemplate, MessagesPlaceholder
from langchain_core.output_parsers import StrOutputParser
from langchain_core.runnables.history import RunnableWithMessageHistory
from langchain_community.chat_message_histories import ChatMessageHistory


class SimpleOpenaiAgent(BaseAgent):
    
    def __init__(self) -> None:
        super().__init__()
        required_env_vars = ['OPENAI_API_KEY', 'OPENAI_BASE_URL', 'OPENAI_MODEL']
        for var in required_env_vars:
            if var not in os.environ or not os.environ[var]:
                raise Exception(f"Environment variable {var} is required but not set, please add it in .env file")
        self.llm = ChatOpenAI(
            api_key=os.environ['OPENAI_API_KEY'],
            base_url=os.environ['OPENAI_BASE_URL'],
            model=os.environ['OPENAI_MODEL'],
            temperature=0.7
        )
        self.store = {}
        prompt = ChatPromptTemplate.from_messages(
            [
                ('system', open("./prompts/simple.md").read()),
                MessagesPlaceholder(variable_name='history'),
                ('user', '{input}')
            ]
        )
        chain = prompt | self.llm | StrOutputParser()
        self.chain = RunnableWithMessageHistory(
            chain,
            self.get_memory_via_session,
            input_messages_key='input',
            history_messages_key='history'
        )
    
    def get_memory_via_session(self, session_id: str) -> None:
        if session_id not in self.store:
            self.store[session_id] = ChatMessageHistory()
        return self.store[session_id]

    def invoke(self, msg: str) -> str:
        result = self.chain.invoke({'input': msg}, config={"configurable": {"session_id": "test"}})
        return result
EOF
mkdir ./prompts
cat <<EOF > ./prompts/simple.md
# Positioning:
You are an AI chat assistant, and your main task is to engage in conversation with users and provide useful information. You should focus on maintaining brevity and clarity.
# Objective:
Based on user input, deliver a concise and relevant response.
EOF
cat <<EOF > .env
OPENAI_BASE_URL=
OPENAI_API_KEY=
OPENAI_MODEL=
EOF
cat <<EOF > app.py
import streamlit as st
from agents import SimpleOpenaiAgent
from dotenv import load_dotenv;load_dotenv();


st.header("Simple Agent")

if 'simple_agent' not in st.session_state:
    st.session_state['simple_agent'] = SimpleOpenaiAgent()

if 'messages' not in st.session_state:
    st.session_state['messages'] = [
        {"role": "ai", "content": "Hello! I am a simple agent. Ask me anything."}
    ]

def display_chat_messages() -> None:
    if len(st.session_state['messages']) == 0: return
    with st.container(height=600):
        for message in st.session_state['messages']:
            with st.chat_message(message["role"]):
                st.markdown(message["content"])
    st.markdown(
        """
        <div id='end-of-chat'></div>
        <script>
        var element = document.getElementById("end-of-chat");
        element.scrollIntoView({behavior: "smooth"});
        </script>
        """,
        unsafe_allow_html=True,
    )
message = st.chat_input("Say sth...")
if message: 
    st.session_state['messages'].append({"role": "user", "content": message})
    agent = st.session_state['simple_agent']
    result = agent.invoke(message)
    print(result)
    st.session_state['messages'].append({"role": "ai", "content": result})
display_chat_messages()
EOF
cat <<EOF > local_run.sh
streamlit run app.py
EOF