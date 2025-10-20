"""
Concierge Analyzer - V3 Data Models (PythonAnywhere Compatible)
Purpose: Pydantic models for document-oriented entities and curations
Dependencies: pydantic, jsonschema for validation
Architecture: Models match JSON Schema v2020-12 definitions exactly

CHANGE from models_v3.py: EmailStr replaced with str to avoid rust compilation
"""

from datetime import datetime
from typing import Any, Dict, List, Literal, Optional
from pydantic import BaseModel, Field, field_validator, model_validator
import re


# =============================================================================
# SHARED VALIDATORS
# =============================================================================

def validate_non_empty_string(v: str) -> str:
    """Ensure string is not empty or only whitespace"""
    if not v or not v.strip():
        raise ValueError("String cannot be empty or whitespace only")
    return v.strip()


def validate_iso_datetime(v: str) -> str:
    """Validate ISO 8601 datetime format"""
    try:
        datetime.fromisoformat(v.replace('Z', '+00:00'))
        return v
    except ValueError:
        raise ValueError(f"Invalid ISO 8601 datetime: {v}")


# =============================================================================
# BASE METADATA MODEL
# =============================================================================

class BaseMetadata(BaseModel):
    """Base class for flexible metadata storage"""
    class Config:
        extra = 'allow'  # Allow additional fields not defined in schema
        
    def dict(self, **kwargs):
        """Override to include all extra fields"""
        d = super().dict(**kwargs)
        # Include any extra fields that were set
        for key, value in self.__dict__.items():
            if key not in d:
                d[key] = value
        return d


# =============================================================================
# ENTITY MODELS
# =============================================================================

class EntityMetadata(BaseMetadata):
    """
    Flexible metadata for entities
    Allows any additional fields beyond the base structure
    """
    pass


class Entity(BaseModel):
    """
    Main Entity model representing restaurants, users, etc.
    Matches entities.schema.json structure
    """
    entity_id: str = Field(..., min_length=1, description="Unique entity identifier")
    type: Literal['restaurant', 'user', 'admin', 'system'] = Field(
        ..., 
        description="Entity type classification"
    )
    name: str = Field(..., min_length=1, description="Entity display name")
    metadata: EntityMetadata = Field(
        default_factory=EntityMetadata,
        description="Flexible metadata storage"
    )
    created_at: Optional[str] = Field(
        None,
        pattern=r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}',
        description="ISO 8601 creation timestamp"
    )
    updated_at: Optional[str] = Field(
        None,
        pattern=r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}',
        description="ISO 8601 update timestamp"
    )
    
    @field_validator('entity_id', 'name')
    @classmethod
    def validate_non_empty(cls, v: str) -> str:
        return validate_non_empty_string(v)
    
    @field_validator('created_at', 'updated_at')
    @classmethod
    def validate_timestamps(cls, v: Optional[str]) -> Optional[str]:
        if v is not None:
            return validate_iso_datetime(v)
        return v
    
    class Config:
        json_schema_extra = {
            "example": {
                "entity_id": "rest_12345",
                "type": "restaurant",
                "name": "The Italian Place",
                "metadata": {
                    "cuisine": "Italian",
                    "location": "123 Main St",
                    "rating": 4.5
                }
            }
        }


class EntityCreate(BaseModel):
    """Model for creating new entities (without timestamps)"""
    entity_id: str = Field(..., min_length=1)
    type: Literal['restaurant', 'user', 'admin', 'system']
    name: str = Field(..., min_length=1)
    metadata: EntityMetadata = Field(default_factory=EntityMetadata)
    
    @field_validator('entity_id', 'name')
    @classmethod
    def validate_non_empty(cls, v: str) -> str:
        return validate_non_empty_string(v)


class EntityUpdate(BaseModel):
    """Model for updating entities (all fields optional except entity_id)"""
    entity_id: str = Field(..., min_length=1)
    type: Optional[Literal['restaurant', 'user', 'admin', 'system']] = None
    name: Optional[str] = Field(None, min_length=1)
    metadata: Optional[EntityMetadata] = None
    
    @field_validator('entity_id')
    @classmethod
    def validate_id(cls, v: str) -> str:
        return validate_non_empty_string(v)
    
    @field_validator('name')
    @classmethod
    def validate_name_if_present(cls, v: Optional[str]) -> Optional[str]:
        if v is not None:
            return validate_non_empty_string(v)
        return v


# =============================================================================
# CURATION MODELS
# =============================================================================

class Curator(BaseModel):
    """Curator information"""
    id: str = Field(..., min_length=1, description="Curator unique ID")
    name: str = Field(..., min_length=1, description="Curator display name")
    # Changed from EmailStr to str to avoid rust compilation requirement
    email: Optional[str] = Field(None, description="Curator email")
    
    @field_validator('id', 'name')
    @classmethod
    def validate_fields(cls, v: str) -> str:
        return validate_non_empty_string(v)
    
    @field_validator('email')
    @classmethod
    def validate_email_format(cls, v: Optional[str]) -> Optional[str]:
        """Basic email validation without external dependencies"""
        if v is not None:
            # Simple regex for basic email format
            if not re.match(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$', v):
                raise ValueError('Invalid email format')
        return v


class Notes(BaseModel):
    """Public and private notes"""
    public: Optional[str] = Field(None, description="Public-facing notes")
    private: Optional[str] = Field(None, description="Internal curator notes")


class Item(BaseModel):
    """Individual item in a curation list"""
    entity_id: str = Field(..., min_length=1, description="Reference to entity")
    position: int = Field(..., ge=0, description="Item order position")
    notes: Optional[str] = Field(None, description="Item-specific notes")
    metadata: Dict[str, Any] = Field(
        default_factory=dict,
        description="Additional item metadata"
    )
    
    @field_validator('entity_id')
    @classmethod
    def validate_id(cls, v: str) -> str:
        return validate_non_empty_string(v)


class CurationMetadata(BaseMetadata):
    """
    Flexible metadata for curations
    Allows any additional fields beyond the base structure
    """
    pass


class Curation(BaseModel):
    """
    Main Curation model representing curated lists
    Matches curations.schema.json structure
    """
    curation_id: str = Field(..., min_length=1, description="Unique curation identifier")
    title: str = Field(..., min_length=1, description="Curation title")
    description: Optional[str] = Field(None, description="Curation description")
    curator: Curator = Field(..., description="Curator information")
    items: List[Item] = Field(default_factory=list, description="Curated items list")
    notes: Optional[Notes] = Field(None, description="Public and private notes")
    metadata: CurationMetadata = Field(
        default_factory=CurationMetadata,
        description="Flexible metadata storage"
    )
    tags: List[str] = Field(default_factory=list, description="Categorization tags")
    created_at: Optional[str] = Field(
        None,
        pattern=r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}',
        description="ISO 8601 creation timestamp"
    )
    updated_at: Optional[str] = Field(
        None,
        pattern=r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}',
        description="ISO 8601 update timestamp"
    )
    
    @field_validator('curation_id', 'title')
    @classmethod
    def validate_non_empty(cls, v: str) -> str:
        return validate_non_empty_string(v)
    
    @field_validator('created_at', 'updated_at')
    @classmethod
    def validate_timestamps(cls, v: Optional[str]) -> Optional[str]:
        if v is not None:
            return validate_iso_datetime(v)
        return v
    
    @model_validator(mode='after')
    def validate_item_positions(self) -> 'Curation':
        """Ensure item positions are unique and sequential"""
        if self.items:
            positions = [item.position for item in self.items]
            if len(positions) != len(set(positions)):
                raise ValueError("Item positions must be unique")
        return self
    
    class Config:
        json_schema_extra = {
            "example": {
                "curation_id": "cur_12345",
                "title": "Best Italian Restaurants",
                "description": "Top Italian spots in the city",
                "curator": {
                    "id": "curator_001",
                    "name": "John Doe",
                    "email": "john@example.com"
                },
                "items": [
                    {
                        "entity_id": "rest_001",
                        "position": 0,
                        "notes": "Best pasta in town"
                    }
                ],
                "tags": ["italian", "pasta", "fine-dining"]
            }
        }


class CurationCreate(BaseModel):
    """Model for creating new curations (without timestamps)"""
    curation_id: str = Field(..., min_length=1)
    title: str = Field(..., min_length=1)
    description: Optional[str] = None
    curator: Curator
    items: List[Item] = Field(default_factory=list)
    notes: Optional[Notes] = None
    metadata: CurationMetadata = Field(default_factory=CurationMetadata)
    tags: List[str] = Field(default_factory=list)
    
    @field_validator('curation_id', 'title')
    @classmethod
    def validate_non_empty(cls, v: str) -> str:
        return validate_non_empty_string(v)
    
    @model_validator(mode='after')
    def validate_item_positions(self) -> 'CurationCreate':
        if self.items:
            positions = [item.position for item in self.items]
            if len(positions) != len(set(positions)):
                raise ValueError("Item positions must be unique")
        return self


class CurationUpdate(BaseModel):
    """Model for updating curations (all fields optional except curation_id)"""
    curation_id: str = Field(..., min_length=1)
    title: Optional[str] = Field(None, min_length=1)
    description: Optional[str] = None
    curator: Optional[Curator] = None
    items: Optional[List[Item]] = None
    notes: Optional[Notes] = None
    metadata: Optional[CurationMetadata] = None
    tags: Optional[List[str]] = None
    
    @field_validator('curation_id')
    @classmethod
    def validate_id(cls, v: str) -> str:
        return validate_non_empty_string(v)
    
    @field_validator('title')
    @classmethod
    def validate_title_if_present(cls, v: Optional[str]) -> Optional[str]:
        if v is not None:
            return validate_non_empty_string(v)
        return v
    
    @model_validator(mode='after')
    def validate_item_positions_if_present(self) -> 'CurationUpdate':
        if self.items:
            positions = [item.position for item in self.items]
            if len(positions) != len(set(positions)):
                raise ValueError("Item positions must be unique")
        return self


# =============================================================================
# QUERY MODELS
# =============================================================================

class QueryFilters(BaseModel):
    """Flexible query filters for entities or curations"""
    type: Optional[str] = None
    name: Optional[str] = None
    metadata: Optional[Dict[str, Any]] = None
    tags: Optional[List[str]] = None
    
    class Config:
        extra = 'allow'  # Allow additional filter fields


class QueryRequest(BaseModel):
    """Request model for complex queries"""
    filters: QueryFilters = Field(default_factory=QueryFilters)
    sort_by: Optional[str] = Field(None, description="Field to sort by")
    sort_order: Literal['asc', 'desc'] = Field('asc', description="Sort direction")
    limit: int = Field(100, ge=1, le=1000, description="Maximum results")
    offset: int = Field(0, ge=0, description="Pagination offset")
