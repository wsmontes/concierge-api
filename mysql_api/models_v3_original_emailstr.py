"""
Concierge Analyzer - V3 Data Models
Purpose: Pydantic models for document-oriented entities and curations
Dependencies: pydantic, jsonschema for validation
Architecture: Models match JSON Schema v2020-12 definitions exactly
"""

from datetime import datetime
from typing import Any, Dict, List, Literal, Optional
from pydantic import BaseModel, Field, EmailStr, field_validator, model_validator
import re


# =============================================================================
# SHARED VALIDATORS
# =============================================================================

def validate_id_pattern(value: str) -> str:
    """Validate ID follows pattern: lowercase alphanumeric with underscore/hyphen, min 3 chars"""
    pattern = r'^[a-z0-9][a-z0-9_-]{2,}$'
    if not re.match(pattern, value):
        raise ValueError(
            f"ID must be lowercase alphanumeric with underscore/hyphen, min 3 chars: {value}"
        )
    return value


def validate_non_empty_string(value: str) -> str:
    """Validate string is not empty or whitespace-only"""
    if not value or not value.strip():
        raise ValueError("Value cannot be empty or whitespace-only")
    return value


# =============================================================================
# ENTITY MODELS
# =============================================================================

class MetadataItem(BaseModel):
    """Flexible metadata from various sources (collector, APIs, etc.)"""
    type: str = Field(..., min_length=1, description="Metadata type (e.g., 'google_places', 'collector')")
    source: Optional[str] = Field(None, description="Source system or origin")
    importedAt: Optional[datetime] = Field(None, description="Import timestamp")
    created: Optional[Dict[str, Any]] = Field(None, description="Creation metadata")
    modified: Optional[Dict[str, Any]] = Field(None, description="Modification metadata")
    data: Dict[str, Any] = Field(..., description="Actual metadata payload")
    
    class Config:
        extra = "allow"  # Allow additional fields for flexibility


class SyncMetadata(BaseModel):
    """Synchronization metadata for external system integration"""
    serverId: Optional[int] = Field(None, description="ID in external server system")
    status: Literal["synced", "pending", "error", "conflict"] = Field(
        default="pending", 
        description="Sync status"
    )
    lastSyncedAt: Optional[datetime] = Field(None, description="Last successful sync timestamp")
    externalReference: Optional[str] = Field(None, description="External system reference")
    errorMessage: Optional[str] = Field(None, description="Error message if status is 'error'")


class EntityDocument(BaseModel):
    """
    Entity document structure (stored in entities_v3.doc column)
    Matches entities.schema.json minus id/type (stored as columns)
    """
    name: str = Field(..., min_length=1, description="Display name")
    status: Literal["active", "inactive", "draft"] = Field(
        default="draft", 
        description="Entity status"
    )
    externalId: Optional[str] = Field(None, description="External system identifier")
    createdAt: Optional[datetime] = Field(None, description="Creation timestamp")
    updatedAt: Optional[datetime] = Field(None, description="Last update timestamp")
    createdBy: Optional[str] = Field(None, description="Creator user/system")
    updatedBy: Optional[str] = Field(None, description="Last updater user/system")
    sync: Optional[SyncMetadata] = Field(None, description="Sync metadata")
    metadata: List[MetadataItem] = Field(..., min_length=1, description="Metadata array")
    
    @field_validator('name')
    @classmethod
    def validate_name(cls, v: str) -> str:
        return validate_non_empty_string(v)


class Entity(BaseModel):
    """
    Complete entity model (row in entities_v3 table)
    Includes both column fields and JSON document
    """
    id: str = Field(..., description="Unique identifier")
    type: Literal["restaurant", "hotel", "attraction", "event", "other"] = Field(
        ..., 
        description="Entity type"
    )
    doc: EntityDocument = Field(..., description="JSON document")
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)
    version: int = Field(default=1, ge=1)
    
    @field_validator('id')
    @classmethod
    def validate_id(cls, v: str) -> str:
        return validate_id_pattern(v)
    
    class Config:
        json_schema_extra = {
            "example": {
                "id": "rest_fogo_de_chao_jardins",
                "type": "restaurant",
                "doc": {
                    "name": "Fogo de Chão - Jardins",
                    "status": "active",
                    "metadata": [
                        {
                            "type": "google_places",
                            "source": "google-places-api",
                            "importedAt": "2025-10-20T18:25:00Z",
                            "data": {
                                "placeId": "gp_abc123",
                                "rating": {"average": 4.5, "totalRatings": 1123}
                            }
                        }
                    ]
                },
                "version": 1
            }
        }


# =============================================================================
# CURATION MODELS
# =============================================================================

class Curator(BaseModel):
    """Curator information"""
    id: str = Field(..., min_length=1, description="Curator unique ID")
    name: str = Field(..., min_length=1, description="Curator display name")
    email: Optional[EmailStr] = Field(None, description="Curator email")
    
    @field_validator('id', 'name')
    @classmethod
    def validate_fields(cls, v: str) -> str:
        return validate_non_empty_string(v)


class Notes(BaseModel):
    """Public and private notes"""
    public: str = Field(default="", description="Public notes visible to clients")
    private: str = Field(default="", description="Private notes for curators only")


class CurationDocument(BaseModel):
    """
    Curation document structure (stored in curations_v3.doc column)
    Matches curations.schema.json minus id/entityId (stored as columns)
    """
    curator: Curator = Field(..., description="Curator information")
    createdAt: datetime = Field(..., description="Creation timestamp")
    updatedAt: Optional[datetime] = Field(None, description="Last update timestamp")
    notes: Optional[Notes] = Field(default_factory=Notes, description="Public/private notes")
    categories: Dict[str, List[str]] = Field(
        ..., 
        description="Category -> concepts mapping (all lowercase keys)"
    )
    sources: List[str] = Field(
        default_factory=list, 
        description="Citation sources"
    )
    
    @field_validator('categories')
    @classmethod
    def validate_categories(cls, v: Dict[str, List[str]]) -> Dict[str, List[str]]:
        """Ensure category keys are lowercase and concepts are non-empty"""
        if not v:
            raise ValueError("Categories must have at least one category")
        
        validated = {}
        for key, concepts in v.items():
            # Validate key is lowercase
            if not re.match(r'^[a-z0-9_\-]+$', key):
                raise ValueError(f"Category key must be lowercase: {key}")
            
            # Validate concepts are non-empty strings
            if not concepts:
                raise ValueError(f"Category {key} must have at least one concept")
            
            validated_concepts = []
            for concept in concepts:
                if not concept or not concept.strip():
                    raise ValueError(f"Empty concept in category {key}")
                validated_concepts.append(concept)
            
            # Ensure uniqueness
            if len(validated_concepts) != len(set(validated_concepts)):
                raise ValueError(f"Duplicate concepts in category {key}")
            
            validated[key] = validated_concepts
        
        return validated
    
    @field_validator('sources')
    @classmethod
    def validate_sources(cls, v: List[str]) -> List[str]:
        """Ensure sources are non-empty if present"""
        if v:  # Only validate if sources are provided
            for source in v:
                if not source or not source.strip():
                    raise ValueError("Empty source string not allowed")
        return v


class Curation(BaseModel):
    """
    Complete curation model (row in curations_v3 table)
    Includes both column fields and JSON document
    """
    id: str = Field(..., description="Unique identifier (pattern: cur_{curator}_{entity})")
    entity_id: str = Field(..., description="Reference to entity ID")
    doc: CurationDocument = Field(..., description="JSON document")
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)
    version: int = Field(default=1, ge=1)
    
    @field_validator('id', 'entity_id')
    @classmethod
    def validate_ids(cls, v: str) -> str:
        return validate_id_pattern(v)
    
    class Config:
        json_schema_extra = {
            "example": {
                "id": "cur_wagner_rest_fogo_de_chao_jardins",
                "entity_id": "rest_fogo_de_chao_jardins",
                "doc": {
                    "curator": {
                        "id": "curator_wagner",
                        "name": "Wagner"
                    },
                    "createdAt": "2025-10-20T18:27:00Z",
                    "categories": {
                        "cuisine": ["brazilian", "barbecue"],
                        "mood": ["lively", "executive"]
                    },
                    "sources": ["audio 2025-09-09"]
                },
                "version": 1
            }
        }


# =============================================================================
# REQUEST/RESPONSE MODELS FOR API
# =============================================================================

class EntityCreateRequest(BaseModel):
    """Request model for creating a new entity"""
    id: str
    type: Literal["restaurant", "hotel", "attraction", "event", "other"]
    doc: EntityDocument
    
    @field_validator('id')
    @classmethod
    def validate_id(cls, v: str) -> str:
        return validate_id_pattern(v)


class EntityUpdateRequest(BaseModel):
    """Request model for updating an entity (partial updates allowed)"""
    doc: Dict[str, Any]  # Allow partial document updates
    version: Optional[int] = Field(None, description="For optimistic locking")


class CurationCreateRequest(BaseModel):
    """Request model for creating a new curation"""
    id: str
    entity_id: str
    doc: CurationDocument
    
    @field_validator('id', 'entity_id')
    @classmethod
    def validate_ids(cls, v: str) -> str:
        return validate_id_pattern(v)


class CurationUpdateRequest(BaseModel):
    """Request model for updating a curation (partial updates allowed)"""
    doc: Dict[str, Any]  # Allow partial document updates
    version: Optional[int] = Field(None, description="For optimistic locking")


class QueryFilter(BaseModel):
    """Single filter condition for query DSL"""
    path: str = Field(..., description="JSON path (e.g., '$.name')")
    operator: Literal["=", "!=", ">", ">=", "<", "<=", "like", "in", "contains"] = Field(
        ..., 
        description="Comparison operator"
    )
    value: Any = Field(..., description="Value to compare against")


class QueryRequest(BaseModel):
    """Request model for flexible query DSL"""
    from_table: Literal["entities", "curations"] = Field(..., alias="from")
    filters: List[QueryFilter] = Field(default_factory=list)
    explode: Optional[Dict[str, str]] = Field(
        None, 
        description="Explode array: {'path': '$.categories.mood', 'as': 'concept'}"
    )
    limit: int = Field(default=50, ge=1, le=1000)
    offset: int = Field(default=0, ge=0)
    
    class Config:
        populate_by_name = True  # Allow 'from' as alias


class PaginatedResponse(BaseModel):
    """Generic paginated response"""
    total: int
    limit: int
    offset: int
    items: List[Any]


# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

def entity_to_dict(entity: Entity) -> Dict[str, Any]:
    """Convert Entity model to dictionary suitable for database storage"""
    return {
        "id": entity.id,
        "type": entity.type,
        "doc": entity.doc.model_dump(mode='json', exclude_none=True),
        "created_at": entity.created_at,
        "updated_at": entity.updated_at,
        "version": entity.version
    }


def curation_to_dict(curation: Curation) -> Dict[str, Any]:
    """Convert Curation model to dictionary suitable for database storage"""
    return {
        "id": curation.id,
        "entity_id": curation.entity_id,
        "doc": curation.doc.model_dump(mode='json', exclude_none=True),
        "created_at": curation.created_at,
        "updated_at": curation.updated_at,
        "version": curation.version
    }
