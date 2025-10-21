"""
Concierge API - V3 Database Layer
Purpose: Database connection and JSON query helpers for V3 schema
Dependencies: mysql-connector-python, models_v3
Architecture: Document-oriented queries with JSON_EXTRACT and JSON_TABLE
"""

import json
from contextlib import contextmanager
from datetime import datetime
from typing import Any, Dict, List, Optional, Tuple
import mysql.connector
from mysql.connector import Error as MySQLError
from mysql.connector.pooling import MySQLConnectionPool

from models_v3 import (
    Entity, Curation,
    QueryFilter, QueryRequest
)


# =============================================================================
# DATABASE CONNECTION
# =============================================================================

class DatabaseV3:
    """
    Database connection manager for V3 schema
    Handles connection pooling and JSON document operations
    """
    
    def __init__(
        self,
        host: str = "localhost",
        port: int = 3306,
        user: str = "root",
        password: str = "",
        database: str = "concierge",
        pool_name: str = "concierge_v3_pool",
        pool_size: int = 5
    ):
        """Initialize database connection pool"""
        self.config = {
            "host": host,
            "port": port,
            "user": user,
            "password": password,
            "database": database,
            "pool_name": pool_name,
            "pool_size": pool_size,
            "autocommit": False,
            "charset": "utf8mb4",
            "use_unicode": True,
            # Additional settings for PythonAnywhere stability
            "connection_timeout": 30,
            "pool_reset_session": True,
            "sql_mode": 'TRADITIONAL'
        }
        
        try:
            self.pool = MySQLConnectionPool(**self.config)
            print(f"Database connection pool initialized successfully")
        except MySQLError as e:
            print(f"Failed to initialize database pool: {e}")
            raise RuntimeError(f"Failed to create connection pool: {e}")
    
    @contextmanager
    def get_connection(self):
        """Context manager for database connections with improved error handling"""
        connection = None
        try:
            connection = self.pool.get_connection()
            if not connection.is_connected():
                connection.reconnect(attempts=3, delay=1)
            yield connection
        except MySQLError as e:
            print(f"Failed to get database connection: {e}")
            if connection:
                try:
                    connection.rollback()
                except:
                    pass  # Ignore rollback errors on failed connections
            raise RuntimeError(f"Database operation failed: {e}")
        finally:
            if connection and connection.is_connected():
                try:
                    connection.close()
                except:
                    pass  # Ignore close errors
    
    @contextmanager
    def get_cursor(self, dictionary=True, buffered=True):
        """Context manager for database cursor"""
        with self.get_connection() as connection:
            cursor = connection.cursor(dictionary=dictionary, buffered=buffered)
            try:
                yield cursor, connection
            finally:
                cursor.close()


# =============================================================================
# ENTITY OPERATIONS
# =============================================================================

class EntityRepository:
    """Repository for entity CRUD operations"""
    
    def __init__(self, db: DatabaseV3):
        self.db = db
    
    def create(self, entity: Entity) -> Entity:
        """
        Create a new entity
        Raises: ValueError if entity already exists
        """
        sql = """
            INSERT INTO entities_v3 (id, type, doc, created_at, updated_at, version)
            VALUES (%s, %s, %s, %s, %s, %s)
        """
        
        doc_json = json.dumps(entity.doc.model_dump(mode='json', exclude_none=True))
        
        with self.db.get_cursor() as (cursor, connection):
            try:
                cursor.execute(sql, (
                    entity.id,
                    entity.type,
                    doc_json,
                    entity.created_at,
                    entity.updated_at,
                    entity.version
                ))
                connection.commit()
                return entity
            except MySQLError as e:
                connection.rollback()
                if e.errno == 1062:  # Duplicate entry
                    raise ValueError(f"Entity with id '{entity.id}' already exists")
                raise
    
    def get_by_id(self, entity_id: str) -> Optional[Entity]:
        """Get entity by ID"""
        sql = """
            SELECT id, type, doc, created_at, updated_at, version
            FROM entities_v3
            WHERE id = %s
        """
        
        with self.db.get_cursor() as (cursor, _):
            cursor.execute(sql, (entity_id,))
            row = cursor.fetchone()
            
            if not row:
                return None
            
            return Entity(
                id=row['id'],
                type=row['type'],
                doc=Entity(**json.loads(row['doc'])),
                created_at=row['created_at'],
                updated_at=row['updated_at'],
                version=row['version']
            )
    
    def update(
        self, 
        entity_id: str, 
        doc_updates: Dict[str, Any],
        expected_version: Optional[int] = None
    ) -> Entity:
        """
        Update entity using JSON_MERGE_PATCH
        Supports optimistic locking via expected_version
        """
        # Build WHERE clause with optional version check
        where_clause = "WHERE id = %s"
        params = [json.dumps(doc_updates), entity_id]
        
        if expected_version is not None:
            where_clause += " AND version = %s"
            params.append(expected_version)
        
        sql = f"""
            UPDATE entities_v3
            SET doc = JSON_MERGE_PATCH(doc, %s),
                updated_at = CURRENT_TIMESTAMP(3),
                version = version + 1
            {where_clause}
        """
        
        with self.db.get_cursor() as (cursor, connection):
            cursor.execute(sql, params)
            
            if cursor.rowcount == 0:
                connection.rollback()
                if expected_version is not None:
                    raise ValueError(
                        f"Version conflict: entity '{entity_id}' was modified by another process"
                    )
                raise ValueError(f"Entity '{entity_id}' not found")
            
            connection.commit()
            
            # Fetch updated entity
            updated = self.get_by_id(entity_id)
            if not updated:
                raise RuntimeError("Failed to fetch updated entity")
            
            return updated
    
    def delete(self, entity_id: str) -> bool:
        """
        Delete entity (cascades to curations)
        Returns: True if deleted, False if not found
        """
        sql = "DELETE FROM entities_v3 WHERE id = %s"
        
        with self.db.get_cursor() as (cursor, connection):
            cursor.execute(sql, (entity_id,))
            deleted = cursor.rowcount > 0
            connection.commit()
            return deleted
    
    def list_by_type(
        self, 
        entity_type: str,
        limit: int = 50,
        offset: int = 0
    ) -> List[Entity]:
        """List entities by type with pagination"""
        sql = """
            SELECT id, type, doc, created_at, updated_at, version
            FROM entities_v3
            WHERE type = %s
            ORDER BY updated_at DESC
            LIMIT %s OFFSET %s
        """
        
        with self.db.get_cursor() as (cursor, _):
            cursor.execute(sql, (entity_type, limit, offset))
            rows = cursor.fetchall()
            
            return [
                Entity(
                    id=row['id'],
                    type=row['type'],
                    doc=Entity(**json.loads(row['doc'])),
                    created_at=row['created_at'],
                    updated_at=row['updated_at'],
                    version=row['version']
                )
                for row in rows
            ]
    
    def search_by_name(self, name_pattern: str, limit: int = 50) -> List[Entity]:
        """Search entities by name (case-insensitive, uses functional index)"""
        sql = """
            SELECT id, type, doc, created_at, updated_at, version
            FROM entities_v3
            WHERE LOWER(JSON_UNQUOTE(JSON_EXTRACT(doc, '$.name'))) LIKE LOWER(%s)
            ORDER BY JSON_UNQUOTE(JSON_EXTRACT(doc, '$.name'))
            LIMIT %s
        """
        
        with self.db.get_cursor() as (cursor, _):
            cursor.execute(sql, (f"%{name_pattern}%", limit))
            rows = cursor.fetchall()
            
            return [
                Entity(
                    id=row['id'],
                    type=row['type'],
                    doc=Entity(**json.loads(row['doc'])),
                    created_at=row['created_at'],
                    updated_at=row['updated_at'],
                    version=row['version']
                )
                for row in rows
            ]


# =============================================================================
# CURATION OPERATIONS
# =============================================================================

class CurationRepository:
    """Repository for curation CRUD operations"""
    
    def __init__(self, db: DatabaseV3):
        self.db = db
    
    def create(self, curation: Curation) -> Curation:
        """
        Create a new curation
        Raises: ValueError if curation already exists or entity doesn't exist
        """
        sql = """
            INSERT INTO curations_v3 (id, entity_id, doc, created_at, updated_at, version)
            VALUES (%s, %s, %s, %s, %s, %s)
        """
        
        doc_json = json.dumps(curation.doc.model_dump(mode='json', exclude_none=True))
        
        with self.db.get_cursor() as (cursor, connection):
            try:
                cursor.execute(sql, (
                    curation.id,
                    curation.entity_id,
                    doc_json,
                    curation.created_at,
                    curation.updated_at,
                    curation.version
                ))
                connection.commit()
                return curation
            except MySQLError as e:
                connection.rollback()
                if e.errno == 1062:  # Duplicate entry
                    raise ValueError(f"Curation with id '{curation.id}' already exists")
                if e.errno == 1452:  # Foreign key constraint
                    raise ValueError(f"Entity '{curation.entity_id}' does not exist")
                raise
    
    def get_by_id(self, curation_id: str) -> Optional[Curation]:
        """Get curation by ID"""
        sql = """
            SELECT id, entity_id, doc, created_at, updated_at, version
            FROM curations_v3
            WHERE id = %s
        """
        
        with self.db.get_cursor() as (cursor, _):
            cursor.execute(sql, (curation_id,))
            row = cursor.fetchone()
            
            if not row:
                return None
            
            return Curation(
                id=row['id'],
                entity_id=row['entity_id'],
                doc=Curation(**json.loads(row['doc'])),
                created_at=row['created_at'],
                updated_at=row['updated_at'],
                version=row['version']
            )
    
    def get_by_entity(self, entity_id: str) -> List[Curation]:
        """Get all curations for an entity"""
        sql = """
            SELECT id, entity_id, doc, created_at, updated_at, version
            FROM curations_v3
            WHERE entity_id = %s
            ORDER BY created_at DESC
        """
        
        with self.db.get_cursor() as (cursor, _):
            cursor.execute(sql, (entity_id,))
            rows = cursor.fetchall()
            
            return [
                Curation(
                    id=row['id'],
                    entity_id=row['entity_id'],
                    doc=Curation(**json.loads(row['doc'])),
                    created_at=row['created_at'],
                    updated_at=row['updated_at'],
                    version=row['version']
                )
                for row in rows
            ]
    
    def update(
        self, 
        curation_id: str, 
        doc_updates: Dict[str, Any],
        expected_version: Optional[int] = None
    ) -> Curation:
        """
        Update curation using JSON_MERGE_PATCH
        Supports optimistic locking via expected_version
        """
        where_clause = "WHERE id = %s"
        params = [json.dumps(doc_updates), curation_id]
        
        if expected_version is not None:
            where_clause += " AND version = %s"
            params.append(expected_version)
        
        sql = f"""
            UPDATE curations_v3
            SET doc = JSON_MERGE_PATCH(doc, %s),
                updated_at = CURRENT_TIMESTAMP(3),
                version = version + 1
            {where_clause}
        """
        
        with self.db.get_cursor() as (cursor, connection):
            cursor.execute(sql, params)
            
            if cursor.rowcount == 0:
                connection.rollback()
                if expected_version is not None:
                    raise ValueError(
                        f"Version conflict: curation '{curation_id}' was modified"
                    )
                raise ValueError(f"Curation '{curation_id}' not found")
            
            connection.commit()
            
            updated = self.get_by_id(curation_id)
            if not updated:
                raise RuntimeError("Failed to fetch updated curation")
            
            return updated
    
    def delete(self, curation_id: str) -> bool:
        """
        Delete curation
        Returns: True if deleted, False if not found
        """
        sql = "DELETE FROM curations_v3 WHERE id = %s"
        
        with self.db.get_cursor() as (cursor, connection):
            cursor.execute(sql, (curation_id,))
            deleted = cursor.rowcount > 0
            connection.commit()
            return deleted
    
    def find_by_category_concept(
        self, 
        category: str, 
        concept: str,
        limit: int = 50
    ) -> List[Curation]:
        """
        Find curations where category contains specific concept
        Uses JSON_TABLE to explode array
        """
        sql = f"""
            SELECT DISTINCT c.id, c.entity_id, c.doc, c.created_at, c.updated_at, c.version
            FROM curations_v3 c
            CROSS JOIN JSON_TABLE(
                JSON_EXTRACT(c.doc, '$.categories.{category}'),
                '$[*]' COLUMNS (concept_val VARCHAR(512) PATH '$')
            ) jt
            WHERE jt.concept_val = %s
            LIMIT %s
        """
        
        with self.db.get_cursor() as (cursor, _):
            cursor.execute(sql, (concept, limit))
            rows = cursor.fetchall()
            
            return [
                Curation(
                    id=row['id'],
                    entity_id=row['entity_id'],
                    doc=Curation(**json.loads(row['doc'])),
                    created_at=row['created_at'],
                    updated_at=row['updated_at'],
                    version=row['version']
                )
                for row in rows
            ]


# =============================================================================
# QUERY DSL BUILDER
# =============================================================================

class QueryBuilder:
    """Build SQL queries from QueryRequest DSL"""
    
    @staticmethod
    def build_filter_clause(filter_obj: QueryFilter) -> Tuple[str, Any]:
        """Convert QueryFilter to SQL WHERE clause"""
        operators_map = {
            "=": "=",
            "!=": "!=",
            ">": ">",
            ">=": ">=",
            "<": "<",
            "<=": "<=",
            "like": "LIKE",
            "in": "IN",
            "contains": "LIKE"
        }
        
        sql_operator = operators_map.get(filter_obj.operator)
        if not sql_operator:
            raise ValueError(f"Unsupported operator: {filter_obj.operator}")
        
        # Extract JSON value
        extract_expr = f"JSON_UNQUOTE(JSON_EXTRACT(doc, '{filter_obj.path}'))"
        
        if filter_obj.operator == "like" or filter_obj.operator == "contains":
            return f"{extract_expr} LIKE %s", f"%{filter_obj.value}%"
        elif filter_obj.operator == "in":
            placeholders = ", ".join(["%s"] * len(filter_obj.value))
            return f"{extract_expr} IN ({placeholders})", filter_obj.value
        else:
            return f"{extract_expr} {sql_operator} %s", filter_obj.value
    
    @staticmethod
    def build_query(query_req: QueryRequest) -> Tuple[str, List[Any]]:
        """Build complete SQL query from QueryRequest"""
        table = f"{query_req.from_table}_v3"
        params = []
        
        # Base SELECT
        sql = f"SELECT * FROM {table}"
        
        # Add JSON_TABLE for explode
        if query_req.explode:
            path = query_req.explode.get("path")
            alias = query_req.explode.get("as", "exploded_value")
            sql += f"""
                CROSS JOIN JSON_TABLE(
                    JSON_EXTRACT(doc, '{path}'),
                    '$[*]' COLUMNS ({alias} VARCHAR(512) PATH '$')
                ) jt
            """
        
        # Add WHERE clauses
        if query_req.filters:
            where_clauses = []
            for filter_obj in query_req.filters:
                clause, param = QueryBuilder.build_filter_clause(filter_obj)
                where_clauses.append(clause)
                if isinstance(param, list):
                    params.extend(param)
                else:
                    params.append(param)
            
            sql += " WHERE " + " AND ".join(where_clauses)
        
        # Add pagination
        sql += f" LIMIT {query_req.limit} OFFSET {query_req.offset}"
        
        return sql, params
