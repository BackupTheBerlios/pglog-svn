/* 
pglog: enable change logs on a PostgreSQL database.

$Id$

THIS SOFTWARE IS UNDER MIT LICENSE.
(C) 2006 Perillo Manlio (manlio.perillo@gmail.com)

Read LICENSE file for more informations.
*/


/* 
NOTE: this script must be executed as superuser, since plpythonu is untrusted
      If you want to enable logs to all (newly created) database, execute this script 
      in the template1 database 
*/

CREATE SCHEMA pglog;

-- convenience view
CREATE VIEW pglog.PrimaryKeys AS
       SELECT key.table_schema, key.table_name, key.column_name FROM
       information_schema.key_column_usage AS key, 
       information_schema.table_constraints AS type
       WHERE type.constraint_type = 'PRIMARY KEY';

CREATE SEQUENCE pglog.logs_seq;

-- The main log table
CREATE TABLE pglog.Logs (
       id INTEGER PRIMARY KEY DEFAULT nextval('pglog.logs_seq'),
       date TIMESTAMP,
       username TEXT,  -- the user who made the change
       tablename TEXT, -- name of the modified table, schema qualified
       event TEXT,
       oldrow TEXT,
       newrow TEXT
);

-- XXX we need to use EXTERNAL SECURITY DEFINER
CREATE FUNCTION pglog.log() RETURNS trigger AS $$
       """Logs all changes to a table, updating the pglog.Logs table.
       """
       
       # keep the prepared statement in memory
       if SD.has_key("plan"):
          plan = SD["plan"]
       else:
          plan = plpy.prepare("""
          INSERT INTO pglog.Logs (date, username, tablename, event, oldrow, newrow) 
          VALUES (now(), $1, $2, $3, $4, $5)
          """, 
          ["text"] * 5
          )
          
          SD["plan"] = plan

       table = TD["args"][0]
       event = TD["event"]
       old = TD["old"]
       new = TD["new"]
       
       # obtain the current user 
       rv = plpy.execute("SELECT session_user")[0]
       user = rv["session_user"]
       
       plpy.execute(plan, [user, table, event, old, new])
       plpy.execute("NOTIFY pglog")
$$ EXTERNAL SECURITY DEFINER LANGUAGE plpythonu;

CREATE FUNCTION pglog.enable_log(text) RETURNS text AS $$
       """Enable change logs to the given table.

       Table MUST have a primary key.

       Returns the primary key of the given table
       """
       
       # keep the prepared statement in memory
       if SD.has_key("plan"):
          plan = SD["plan"]
       else:
          plan = plpy.prepare("""
          SELECT column_name FROM pglog.PrimaryKeys 
          WHERE table_schema = $1 AND table_name = $2
          """, 
          ["text"] * 2)
          
          SD["plan"] = plan

       table = args[0]
       if "." in table:
          schema, table = table.split(".")
       else:
          # obtain the current schema
          rv = plpy.execute("SELECT current_schema()")[0]
          schema = rv["current_schema"]

       # obtain the primary key for the table
       rv = plpy.execute(plan, [schema, table])
       pk = rv[0]["column_name"]
       
       # and save it in the global state
       primary_keys = GD.setdefault("pglog.primary_keys", {})
       primary_keys[args[0]] = pk
       
       plpy.execute("""
       CREATE TRIGGER pglog_trigger AFTER INSERT OR UPDATE OR DELETE
       ON %(table)s FOR EACH ROW
       EXECUTE PROCEDURE pglog.log('%(table)s')
       """ % {"table": table}
       )

       return pk
$$ LANGUAGE plpythonu;

CREATE FUNCTION pglog.disable_log(text) RETURNS text AS $$
       """Disable change logs to the given table.
       """
       
       table = args[0]
       
       plpy.execute("""
       DROP TRIGGER pglog_trigger ON %(table)s
       """ % {"table": table}
       )

       del GD["pglog.primary_keys"][table]
       
       return table
$$ LANGUAGE plpythonu;

CREATE FUNCTION pglog.revert(int4) RETURNS text AS $$
       """Revert the specified change.
       """
       
       # keep the prepared statement in memory
       if SD.has_key("plan"):
          plan = SD["plan"]
       else:
          plan = plpy.prepare("""
          SELECT date, username, tablename, event, oldrow, newrow FROM pglog.Logs 
          WHERE id = $1
          """, 
          ["int4"]
          )
          
          SD["plan"] = plan

       id = args[0]

       # get the log data
       rv = plpy.execute(plan, [id])[0]
       
       event = rv["event"]
       table = rv["tablename"]
       old = eval(rv["oldrow"] or "{}")
       new = eval(rv["newrow"] or "{}")
       
       # get the primary key for the table
       pk = GD["pglog.primary_keys"][table]

       # revert the modification
       if event == "DELETE":
          # XXX can fail if an incompatible row exists
          keys = ", ".join(old.keys())
          values = ", ".join("'%s'" % col for col in old.values())

          plpy.execute("""
          INSERT INTO %s (%s) VALUES (%s)
          """ % (table, keys, values)
          )

          return str(old)
       elif event == "INSERT":
          # XXX can fail if the row no longer exists
          plpy.execute("""
          DELETE FROM %s WHERE %s=%s
          """ % (table, pk, new[pk])
          )
          
          return str(new)
       elif event == "UPDATE":
          # XXX can fail if the row has changed
          values = ', '.join("%s='%s'" % (key, val) for key, val in old.items())
          plpy.execute("""
          UPDATE %s SET %s WHERE %s=%s
          """ % (table, values, pk, new[pk])
          )

          return str(new)
       else:
          plpy.error("Invalid event '%s'" % event)
$$ LANGUAGE plpythonu;

CREATE FUNCTION pglog.last_change_id() RETURNS int8 AS $$
       /*Convenience function.

       Return the id of the last change.
       */

       SELECT currval('pglog.logs_seq')
$$ LANGUAGE SQL;

-- setup privileges
-- XXX TODO use roles? (only availables from 8.1)
CREATE GROUP logger;

GRANT USAGE ON SCHEMA pglog TO PUBLIC;
GRANT SELECT ON TABLE pglog.logs_seq TO PUBLIC;
GRANT SELECT ON TABLE pglog.Logs TO PUBLIC;
GRANT DELETE ON TABLE pglog.Logs TO GROUP logger;
GRANT SELECT ON TABLE pglog.PrimaryKeys TO PUBLIC;