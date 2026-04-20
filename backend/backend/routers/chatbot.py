from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel
from typing import List, Optional, Dict, Any
import os
import json
from datetime import datetime

from slowapi import Limiter
from slowapi.util import get_remote_address
from sqlalchemy.orm import Session
from database import get_db
from models import User, Task
from auth import get_current_user
import openai

router = APIRouter(prefix="/chatbot", tags=["Chatbot"])
limiter = Limiter(key_func=get_remote_address)

class ChatMessage(BaseModel):
    role: str
    content: str

class ChatRequest(BaseModel):
    messages: List[ChatMessage]

class ChatResponse(BaseModel):
    response: str

def _get_openai_client():
    api_key = os.getenv("OPENAI_API_KEY")
    if not api_key:
        return None
    try:
        from openai import OpenAI
        return OpenAI(api_key=api_key)
    except Exception:
        return None

# Define the tool schema for creating a task
CREATE_TASK_TOOL = {
    "type": "function",
    "function": {
        "name": "create_task",
        "description": "Creates a new task for the user based on their request.",
        "parameters": {
            "type": "object",
            "properties": {
                "title": {
                    "type": "string",
                    "description": "The title or name of the task."
                },
                "description": {
                    "type": "string",
                    "description": "Optional details about the task."
                },
                "category": {
                    "type": "string",
                    "description": "The category of the task (e.g., Work, Personal, Health, Study, Finance)."
                },
                "priority": {
                    "type": "string",
                    "enum": ["low", "medium", "high"],
                    "description": "The priority of the task. Default to medium if not specified."
                },
                "estimated_minutes": {
                    "type": "integer",
                    "description": "The estimated time to complete the task in minutes. Default to 30."
                }
            },
            "required": ["title"]
        }
    }
}

@router.post("/message", response_model=ChatResponse)
@limiter.limit("20/minute")
async def chat_with_agent(
    request: Request,  # noqa: ARG001 — required by slowapi limiter
    req: ChatRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    client = _get_openai_client()
    if not client:
        raise HTTPException(status_code=503, detail="AI Service is currently unavailable. Missing API Key.")

    # Prepare conversation history
    system_prompt = (
        "You are the FocusFlow AI Assistant, a helpful and concise productivity agent embedded in a task management app. "
        "Your goal is to help the user manage their tasks, answer productivity questions, and proactively create tasks when requested. "
        "Keep your responses relatively brief, friendly, and helpful. "
        f"The current date and time is {datetime.now().strftime('%Y-%m-%d %H:%M')}. "
        "If a user asks you to create a task, remind them, or schedule something, use the `create_task` tool."
    )
    
    messages = [{"role": "system", "content": system_prompt}]
    for msg in req.messages:
        messages.append({"role": msg.role, "content": msg.content})

    try:
        # Initial call to OpenAI
        response = client.chat.completions.create(
            model=os.getenv("OPENAI_MODEL", "gpt-4o"), # or gpt-3.5-turbo if you prefer speed
            messages=messages,
            tools=[CREATE_TASK_TOOL],
            tool_choice="auto"
        )

        response_message = response.choices[0].message
        tool_calls = response_message.tool_calls

        # Check if the AI wanted to call a tool
        if tool_calls:
            messages.append(response_message)
            
            # Execute all requested tool calls
            for tool_call in tool_calls:
                function_name = tool_call.function.name
                
                if function_name == "create_task":
                    try:
                        args = json.loads(tool_call.function.arguments)
                        
                        # Create the task in the database
                        new_task = Task(
                            user_id=current_user.id,
                            title=args.get("title"),
                            description=args.get("description", ""),
                            category=args.get("category", "General"),
                            priority=args.get("priority", "medium"),
                            estimated_minutes=args.get("estimated_minutes", 30),
                            status="todo"
                        )
                        db.add(new_task)
                        db.commit()
                        db.refresh(new_task)
                        
                        # Send the result back to the AI
                        tool_result = f"Successfully created task ID {new_task.id}: '{new_task.title}'"
                    except Exception as e:
                        db.rollback()
                        tool_result = f"Error creating task: {str(e)}"
                        
                    messages.append({
                        "tool_call_id": tool_call.id,
                        "role": "tool",
                        "name": function_name,
                        "content": tool_result,
                    })
            
            # Get the final response from AI after tool execution
            final_response = client.chat.completions.create(
                model=os.getenv("OPENAI_MODEL", "gpt-4o"),
                messages=messages
            )
            return {"response": final_response.choices[0].message.content}
            
        else:
            # AI just wanted to chat normally
            return {"response": response_message.content}

    except Exception as e:
        print(f"Chatbot Error: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to communicate with AI Agent: {str(e)}")
