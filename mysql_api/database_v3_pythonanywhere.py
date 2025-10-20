"""
Concierge Analyzer - V3 Database Layer (PythonAnywhere Compatible)
Purpose: Database layer using MySQLdb (mysqlclient) instead of mysql-connector-python
Dependencies: mysqlclient (MySQLdb), models_v3
Architecture: Document-oriented queries with JSON_EXTRACT and JSON_TABLE
Usage: Rename this to database_v3.py when deploying to PythonAnywhere
"""

import json
from contextlib import contextmanager
from datetime import datetime
from typing import Any, Dict, List, Optional, Tuple

# Try MySQLdb first (PythonAnywhere), fallback to mysql.connector (local)
try:
    import MySQLdb as mysql_client
    from MySQLdb import Error as MySQLError
    USING_MYSQLDB = True
except ImportError:
    import mysql.connector as mysql_client
    from mysql.connector import Error as MySQLError
    from mysql.connector.pooling import MySQLConnectionPool
    USING_MYSQLDB = False

from models_v3 import (
    Entity, EntityDocument, Curation, CurationDocument,
    QueryFilter, QueryRequest
)


# =============================================================================
# DATABASE CONNECTION (DUAL COMPATIBILITY)
# =============================================================================

class DatabaseV3:
    """
    Database connection manager for V3 schema
    Handles connection pooling and JSON document operations
    Compatible with both mysql-connector-python (local) and MySQLdb (PythonAnywhere)
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
            "charset": "utf8mb4",
        }
        
        self.using_mysqldb = USING_MYSQLDB
        
        if self.using_mysqldb:
            # MySQLdb (PythonAnywhere) - no built-in pooling, create connections on demand
            self.pool = None
            self.pool_size = pool_size
        else:
            # mysql-connector-python (local) - use connection pooling
            try:
                self.config["pool_name"] = pool_name
                self.config["pool_size"] = pool_size
                self.config["autocommit"] = False
                self.config["use_unicode"] = True
                self.pool = MySQLConnectionPool(**self.config)
            except MySQLError as e:
                raise RuntimeError(f"Failed to create connection pool: {e}")
    
    @contextmanager
    def get_connection(self):
        """Context manager for database connections"""
        connection = None
        try:
            if self.using_mysqldb:
                # MySQLdb connection
                connection = mysql_client.connect(
                    host=self.config["host"],
                    port=self.config["port"],
                    user=self.config["user"],
                    passwd=self.config["password"],
                    db=self.config["database"],
                    charset=self.config["charset"],
                    use_unicode=True
                )
            else:
                # mysql-connector-python connection
                connection = self.pool.get_connection()
            
            yield connection
        except MySQLError as e:
            if connection:
                connection.rollback()
            raise RuntimeError(f"Database error: {e}")
        finally:
            if connection:
                if self.using_mysqldb and hasattr(connection, 'close'):
                    connection.close()
                elif not self.using_mysqldb and connection.is_connected():
                    connection.close()
    
    @contextmanager
    def get_cursor(self, dictionary=True, buffered=True):
        """Context manager for database cursor"""
        with self.get_connection() as connection:
            if self.using_mysqldb:
                # MySQLdb uses DictCursor for dictionary results
                import MySQLdb.cursors
                cursor = connection.cursor(MySQLdb.cursors.DictCursor) if dictionary else connection.cursor()
            else:
                # mysql-connector-python cursor
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
        
        now = datetime.utcnow()
        doc_json = entity.doc.model_dump_json()
        
        with self.db.get_cursor() as (cursor, conn):
            try:
                cursor.execute(sql, (
                    entity.id,
                    entity.type,
                    doc_json,
                    now,
                    now,
                    1
                ))
                conn.commit()
                
                # Return created entity with timestamps
                return Entity(
                    id=entity.id,
                    type=entity.type,
                    doc=entity.doc,
                    created_at=now,
                    updated_at=now,
                    version=1
                )
            except MySQLError as e:
                if 'Duplicate entry' in str(e):
                    raise ValueError(f"Entity {entity.id} already exists")
                raise
    
    def get(self, entity_id: str) -> Optional[Entity]:
        """Get entity by ID"""
        sql = "SELECT * FROM entities_v3 WHERE id = %s"
        
        with self.db.get_cursor() as (cursor, _):
            cursor.execute(sql, (entity_id,))
            row = cursor.fetchone()
            
            if not row:
                return None
            
            return Entity(
                id=row['id'],
                type=row['type'],
                doc=EntityDocument.model_validate_json(row['doc']),
                created_at=row['created_at'],
                updated_at=row['updated_at'],
                version=row['version']
            )
    
    def update(self, entity_id: str, doc: EntityDocument, if_match: Optional[int] = None) -> Entity:
        """
        Update entity document
        Implements optimistic locking with if_match
        """
        if if_match is not None:
            sql = """
            UPDATE entities_v3 
            SET doc = %s, updated_at = %s, version = version + 1
            WHERE id = %s AND version = %s
            """
            params = (doc.model_dump_json(), datetime.utcnow(), entity_id, if_match)
        else:
            sql = """
            UPDATE entities_v3 
            SET doc = %s, updated_at = %s, version = version + 1
            WHERE id = %s
            """
            params = (doc.model_dump_json(), datetime.utcnow(), entity_id)
        
        with self.db.get_cursor() as (cursor, conn):
            cursor.execute(sql, params)
            
            if cursor.rowcount == 0:
                if if_match is not None:
                    raise ValueError("Version mismatch (precondition failed)")
                raise ValueError(f"Entity {entity_id} not found")
            
            conn.commit()
            
            # Fetch updated entity
            cursor.execute("SELECT * FROM entities_v3 WHERE id = %s", (entity_id,))
            row = cursor.fetchone()
            
            return Entity(
                id=row['id'],
                type=row['type'],
                doc=EntityDocument.model_validate_json(row['doc']),
                created_at=row['created_at'],
                updated_at=row['updated_at'],
                version=row['version']
            )
    
    def delete(self, entity_id: str) -> bool:
        """Delete entity (cascades to curations)"""
        sql = "DELETE FROM entities_v3 WHERE id = %s"
        
        with self.db.get_cursor() as (cursor, conn):
            cursor.execute(sql, (entity_id,))
            deleted = cursor.rowcount > 0
            conn.commit()
            return deleted
    
    def list_all(
        self,
        type_filter: Optional[str] = None,
        status_filter: Optional[str] = None,
        limit: int = 100,
        offset: int = 0
    ) -> List[Entity]:
        """List entities with optional filters"""
        where_clauses = []
        params = []
        
        if type_filter:
            where_clauses.append("type = %s")
            params.append(type_filter)
        
        if status_filter:
            where_clauses.append("JSON_UNQUOTE(JSON_EXTRACT(doc, '$.status')) = %s")
            params.append(status_filter)
        
        where_sql = " AND ".join(where_clauses) if where_clauses else "1=1"
        sql = f"""
        SELECT * FROM entities_v3 
        WHERE {where_sql}
        ORDER BY created_at DESC
        LIMIT %s OFFSET %s
        """
        params.extend([limit, offset])
        
        with self.db.get_cursor() as (cursor, _):
            cursor.execute(sql, tuple(params))
            rows = cursor.fetchall()
            
            return [
                Entity(
                    id=row['id'],
                    type=row['type'],
                    doc=EntityDocument.model_validate_json(row['doc']),
                    created_at=row['created_at'],
                    updated_at=row['updated_at'],
                    version=row['version']
                )
                for row in rows
            ]
    
    def search_by_name(self, name: str, limit: int = 10) -> List[Entity]:
        """Search entities by name (case-insensitive)"""
        sql = """
        SELECT * FROM entities_v3
        WHERE LOWER(JSON_UNQUOTE(JSON_EXTRACT(doc, '$.name'))) LIKE %s
        ORDER BY created_at DESC
        LIMIT %s
        """
        
        with self.db.get_cursor() as (cursor, _):
            cursor.execute(sql, (f"%{name.lower()}%", limit))
            rows = cursor.fetchall()
            
            return [
                Entity(
                    id=row['id'],
                    type=row['type'],
                    doc=EntityDocument.model_validate_json(row['doc']),
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
        Raises: ValueError if entity doesn't exist or curation already exists
        """
        sql = """
        INSERT INTO curations_v3 (id, entity_id, doc, created_at, updated_at, version)
        VALUES (%s, %s, %s, %s, %s, %s)
        """
        
        now = datetime.utcnow()
        doc_json = curation.doc.model_dump_json()
        
        with self.db.get_cursor() as (cursor, conn):
            try:
                cursor.execute(sql, (
                    curation.id,
                    curation.entity_id,
                    doc_json,
                    now,
                    now,
                    1
                ))
                conn.commit()
                
                return Curation(
                    id=curation.id,
                    entity_id=curation.entity_id,
                    doc=curation.doc,
                    created_at=now,
                    updated_at=now,
                    version=1
                )
            except MySQLError as e:
                if 'Duplicate entry' in str(e):
                    raise ValueError(f"Curation {curation.id} already exists")
                if 'foreign key constraint' in str(e).lower():
                    raise ValueError(f"Entity {curation.entity_id} not found")
                raise
    
    def get(self, curation_id: str) -> Optional[Curation]:
        """Get curation by ID"""
        sql = "SELECT * FROM curations_v3 WHERE id = %s"
        
        with self.db.get_cursor() as (cursor, _):
            cursor.execute(sql, (curation_id,))
            row = cursor.fetchone()
            
            if not row:
                return None
            
            return Curation(
                id=row['id'],
                entity_id=row['entity_id'],
                doc=CurationDocument.model_validate_json(row['doc']),
                created_at=row['created_at'],
                updated_at=row['updated_at'],
                version=row['version']
            )
    
    def list_by_entity(self, entity_id: str) -> List[Curation]:
        """List all curations for an entity"""
        sql = """
        SELECT * FROM curations_v3 
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
                    doc=CurationDocument.model_validate_json(row['doc']),
                    created_at=row['created_at'],
                    updated_at=row['updated_at'],
                    version=row['version']
                )
                for row in rows
            ]
    
    def delete(self, curation_id: str) -> bool:
        """Delete curation"""
        sql = "DELETE FROM curations_v3 WHERE id = %s"
        
        with self.db.get_cursor() as (cursor, conn):
            cursor.execute(sql, (curation_id,))
            deleted = cursor.rowcount > 0
            conn.commit()
            return deleted


# Note: QueryBuilder and execute_query methods follow the same pattern
# Omitted here for brevity - they remain identical to the original database_v3.py
