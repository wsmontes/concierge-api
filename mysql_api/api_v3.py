"""
Concierge Analyzer - V3 REST API
Purpose: Flask REST API for entities and curations with document-oriented operations
Dependencies: Flask, models_v3, database_v3
Architecture: RESTful endpoints with JSON validation and optimistic locking
"""

from datetime import datetime
from typing import Any, Dict, List
from flask import Blueprint, Flask, jsonify, request
from pydantic import ValidationError
import json

from models_v3 import (
    Entity, EntityCreateRequest, EntityUpdateRequest,
    Curation, CurationCreateRequest, CurationUpdateRequest,
    QueryRequest, QueryFilter
)
from database_v3 import DatabaseV3, EntityRepository, CurationRepository, QueryBuilder


# =============================================================================
# BLUEPRINT SETUP
# =============================================================================

api_v3 = Blueprint('api_v3', __name__, url_prefix='/api/v3')


# =============================================================================
# DEPENDENCY INJECTION (will be initialized by app factory)
# =============================================================================

db: DatabaseV3 = None
entity_repo: EntityRepository = None
curation_repo: CurationRepository = None


def init_v3_api(app: Flask, database: DatabaseV3):
    """Initialize V3 API with database connection"""
    global db, entity_repo, curation_repo
    db = database
    entity_repo = EntityRepository(db)
    curation_repo = CurationRepository(db)
    app.register_blueprint(api_v3)


# =============================================================================
# ERROR HANDLERS
# =============================================================================

@api_v3.errorhandler(ValidationError)
def handle_validation_error(e: ValidationError):
    """Handle Pydantic validation errors"""
    return jsonify({
        "error": "Validation error",
        "details": e.errors()
    }), 400


@api_v3.errorhandler(ValueError)
def handle_value_error(e: ValueError):
    """Handle business logic errors"""
    return jsonify({
        "error": "Invalid request",
        "message": str(e)
    }), 400


@api_v3.errorhandler(RuntimeError)
def handle_runtime_error(e: RuntimeError):
    """Handle database/system errors"""
    return jsonify({
        "error": "Server error",
        "message": str(e)
    }), 500


# =============================================================================
# ENTITY ENDPOINTS
# =============================================================================

@api_v3.route('/entities', methods=['POST'])
def create_entity():
    """
    Create a new entity
    
    Request body:
    {
      "id": "rest_example",
      "type": "restaurant",
      "doc": {
        "name": "Example Restaurant",
        "status": "draft",
        "metadata": [...]
      }
    }
    """
    try:
        data = request.get_json()
        req = EntityCreateRequest(**data)
        
        # Create Entity model with timestamps
        entity = Entity(
            id=req.id,
            type=req.type,
            doc=req.doc,
            created_at=datetime.utcnow(),
            updated_at=datetime.utcnow(),
            version=1
        )
        
        created = entity_repo.create(entity)
        
        return jsonify({
            "id": created.id,
            "type": created.type,
            "doc": created.doc.model_dump(mode='json', exclude_none=True),
            "created_at": created.created_at.isoformat(),
            "updated_at": created.updated_at.isoformat(),
            "version": created.version
        }), 201
        
    except ValidationError as e:
        return handle_validation_error(e)


@api_v3.route('/entities/<entity_id>', methods=['GET'])
def get_entity(entity_id: str):
    """Get entity by ID"""
    entity = entity_repo.get_by_id(entity_id)
    
    if not entity:
        return jsonify({"error": "Entity not found"}), 404
    
    return jsonify({
        "id": entity.id,
        "type": entity.type,
        "doc": entity.doc.model_dump(mode='json', exclude_none=True),
        "created_at": entity.created_at.isoformat(),
        "updated_at": entity.updated_at.isoformat(),
        "version": entity.version
    })


@api_v3.route('/entities/<entity_id>', methods=['PATCH'])
def update_entity(entity_id: str):
    """
    Update entity (partial update with JSON_MERGE_PATCH)
    
    Request body:
    {
      "doc": {
        "status": "active",
        "metadata": [...]
      },
      "version": 1  // Optional: for optimistic locking
    }
    
    Headers:
    If-Match: <version>  // Alternative to body version
    """
    try:
        data = request.get_json()
        req = EntityUpdateRequest(**data)
        
        # Check for version in If-Match header
        if_match = request.headers.get('If-Match')
        expected_version = req.version or (int(if_match) if if_match else None)
        
        updated = entity_repo.update(entity_id, req.doc, expected_version)
        
        return jsonify({
            "id": updated.id,
            "type": updated.type,
            "doc": updated.doc.model_dump(mode='json', exclude_none=True),
            "created_at": updated.created_at.isoformat(),
            "updated_at": updated.updated_at.isoformat(),
            "version": updated.version
        })
        
    except ValidationError as e:
        return handle_validation_error(e)


@api_v3.route('/entities/<entity_id>', methods=['DELETE'])
def delete_entity(entity_id: str):
    """Delete entity (cascades to curations)"""
    deleted = entity_repo.delete(entity_id)
    
    if not deleted:
        return jsonify({"error": "Entity not found"}), 404
    
    return '', 204


@api_v3.route('/entities', methods=['GET'])
def list_entities():
    """
    List entities with optional filtering
    
    Query params:
    - type: Filter by entity type (restaurant, hotel, etc.)
    - name: Search by name (partial match)
    - limit: Page size (default 50)
    - offset: Pagination offset (default 0)
    """
    entity_type = request.args.get('type')
    name_query = request.args.get('name')
    limit = int(request.args.get('limit', 50))
    offset = int(request.args.get('offset', 0))
    
    # Search by name if provided
    if name_query:
        entities = entity_repo.search_by_name(name_query, limit)
    # Filter by type if provided
    elif entity_type:
        entities = entity_repo.list_by_type(entity_type, limit, offset)
    else:
        return jsonify({"error": "Must provide 'type' or 'name' parameter"}), 400
    
    return jsonify({
        "items": [
            {
                "id": e.id,
                "type": e.type,
                "doc": e.doc.model_dump(mode='json', exclude_none=True),
                "created_at": e.created_at.isoformat(),
                "updated_at": e.updated_at.isoformat(),
                "version": e.version
            }
            for e in entities
        ],
        "limit": limit,
        "offset": offset
    })


# =============================================================================
# CURATION ENDPOINTS
# =============================================================================

@api_v3.route('/curations', methods=['POST'])
def create_curation():
    """
    Create a new curation
    
    Request body:
    {
      "id": "cur_wagner_rest_example",
      "entity_id": "rest_example",
      "doc": {
        "curator": {"id": "curator_wagner", "name": "Wagner"},
        "createdAt": "2025-10-20T18:27:00Z",
        "categories": {...},
        "sources": [...]
      }
    }
    """
    try:
        data = request.get_json()
        req = CurationCreateRequest(**data)
        
        curation = Curation(
            id=req.id,
            entity_id=req.entity_id,
            doc=req.doc,
            created_at=datetime.utcnow(),
            updated_at=datetime.utcnow(),
            version=1
        )
        
        created = curation_repo.create(curation)
        
        return jsonify({
            "id": created.id,
            "entity_id": created.entity_id,
            "doc": created.doc.model_dump(mode='json', exclude_none=True),
            "created_at": created.created_at.isoformat(),
            "updated_at": created.updated_at.isoformat(),
            "version": created.version
        }), 201
        
    except ValidationError as e:
        return handle_validation_error(e)


@api_v3.route('/curations/<curation_id>', methods=['GET'])
def get_curation(curation_id: str):
    """Get curation by ID"""
    curation = curation_repo.get_by_id(curation_id)
    
    if not curation:
        return jsonify({"error": "Curation not found"}), 404
    
    return jsonify({
        "id": curation.id,
        "entity_id": curation.entity_id,
        "doc": curation.doc.model_dump(mode='json', exclude_none=True),
        "created_at": curation.created_at.isoformat(),
        "updated_at": curation.updated_at.isoformat(),
        "version": curation.version
    })


@api_v3.route('/curations/<curation_id>', methods=['PATCH'])
def update_curation(curation_id: str):
    """
    Update curation (partial update)
    
    Request body:
    {
      "doc": {
        "categories": {
          "mood": ["lively", "executive", "romantic"]
        }
      },
      "version": 1  // Optional: for optimistic locking
    }
    """
    try:
        data = request.get_json()
        req = CurationUpdateRequest(**data)
        
        if_match = request.headers.get('If-Match')
        expected_version = req.version or (int(if_match) if if_match else None)
        
        updated = curation_repo.update(curation_id, req.doc, expected_version)
        
        return jsonify({
            "id": updated.id,
            "entity_id": updated.entity_id,
            "doc": updated.doc.model_dump(mode='json', exclude_none=True),
            "created_at": updated.created_at.isoformat(),
            "updated_at": updated.updated_at.isoformat(),
            "version": updated.version
        })
        
    except ValidationError as e:
        return handle_validation_error(e)


@api_v3.route('/curations/<curation_id>', methods=['DELETE'])
def delete_curation(curation_id: str):
    """Delete curation"""
    deleted = curation_repo.delete(curation_id)
    
    if not deleted:
        return jsonify({"error": "Curation not found"}), 404
    
    return '', 204


@api_v3.route('/entities/<entity_id>/curations', methods=['GET'])
def get_entity_curations(entity_id: str):
    """Get all curations for a specific entity"""
    curations = curation_repo.get_by_entity(entity_id)
    
    return jsonify({
        "entity_id": entity_id,
        "curations": [
            {
                "id": c.id,
                "doc": c.doc.model_dump(mode='json', exclude_none=True),
                "created_at": c.created_at.isoformat(),
                "updated_at": c.updated_at.isoformat(),
                "version": c.version
            }
            for c in curations
        ]
    })


@api_v3.route('/curations/search', methods=['GET'])
def search_curations():
    """
    Search curations by category and concept
    
    Query params:
    - category: Category name (e.g., 'mood', 'cuisine')
    - concept: Concept value (e.g., 'lively', 'brazilian')
    - limit: Results limit (default 50)
    """
    category = request.args.get('category')
    concept = request.args.get('concept')
    limit = int(request.args.get('limit', 50))
    
    if not category or not concept:
        return jsonify({
            "error": "Must provide both 'category' and 'concept' parameters"
        }), 400
    
    curations = curation_repo.find_by_category_concept(category, concept, limit)
    
    return jsonify({
        "category": category,
        "concept": concept,
        "curations": [
            {
                "id": c.id,
                "entity_id": c.entity_id,
                "doc": c.doc.model_dump(mode='json', exclude_none=True),
                "created_at": c.created_at.isoformat(),
                "updated_at": c.updated_at.isoformat(),
                "version": c.version
            }
            for c in curations
        ]
    })


# =============================================================================
# QUERY DSL ENDPOINT
# =============================================================================

@api_v3.route('/query', methods=['POST'])
def execute_query():
    """
    Execute flexible query using DSL
    
    Request body:
    {
      "from": "entities",
      "filters": [
        {"path": "$.name", "operator": "like", "value": "Fogo"},
        {"path": "$.status", "operator": "=", "value": "active"}
      ],
      "limit": 20,
      "offset": 0
    }
    
    Or with explode:
    {
      "from": "curations",
      "explode": {"path": "$.categories.mood", "as": "mood"},
      "filters": [
        {"path": "mood", "operator": "=", "value": "lively"}
      ]
    }
    """
    try:
        data = request.get_json()
        query_req = QueryRequest(**data)
        
        sql, params = QueryBuilder.build_query(query_req)
        
        with db.get_cursor() as (cursor, _):
            cursor.execute(sql, params)
            rows = cursor.fetchall()
            
            return jsonify({
                "query": query_req.model_dump(mode='json'),
                "total": len(rows),
                "items": rows
            })
            
    except ValidationError as e:
        return handle_validation_error(e)
    except Exception as e:
        return jsonify({
            "error": "Query execution failed",
            "message": str(e)
        }), 500


# =============================================================================
# HEALTH & INFO ENDPOINTS
# =============================================================================

@api_v3.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    try:
        with db.get_cursor() as (cursor, _):
            cursor.execute("SELECT 1")
            cursor.fetchone()
        
        return jsonify({
            "status": "healthy",
            "version": "3.0",
            "database": "connected"
        })
    except Exception as e:
        return jsonify({
            "status": "unhealthy",
            "error": str(e)
        }), 503


@api_v3.route('/info', methods=['GET'])
def api_info():
    """API information and capabilities"""
    return jsonify({
        "version": "3.0",
        "description": "Document-oriented REST API for Concierge Analyzer",
        "endpoints": {
            "entities": {
                "POST /api/v3/entities": "Create entity",
                "GET /api/v3/entities/<id>": "Get entity",
                "PATCH /api/v3/entities/<id>": "Update entity (partial)",
                "DELETE /api/v3/entities/<id>": "Delete entity",
                "GET /api/v3/entities?type=X": "List entities by type",
                "GET /api/v3/entities?name=X": "Search entities by name"
            },
            "curations": {
                "POST /api/v3/curations": "Create curation",
                "GET /api/v3/curations/<id>": "Get curation",
                "PATCH /api/v3/curations/<id>": "Update curation (partial)",
                "DELETE /api/v3/curations/<id>": "Delete curation",
                "GET /api/v3/entities/<id>/curations": "Get entity curations",
                "GET /api/v3/curations/search?category=X&concept=Y": "Search curations"
            },
            "query": {
                "POST /api/v3/query": "Execute flexible query DSL"
            }
        },
        "features": [
            "Document-oriented storage",
            "JSON_MERGE_PATCH for partial updates",
            "Optimistic locking with version control",
            "Functional indexes on JSON paths",
            "JSON_TABLE for array queries",
            "Flexible query DSL"
        ]
    })
