-- NOTE: this script must be executed as superuser, since plpythonu is untrusted
-- If you want to enable logs to all (newly created) database, execute this script 
-- in the template1 database 
-- XXX TODO add comments

CREATE SCHEMA pglog;

-- The main log table
CREATE TABLE pglog.Logs (
       id SERIAL PRIMARY KEY,
       date TIMESTAMP,
       tablename TEXT,
       event TEXT,
       oldrow TEXT,
       newrow TEXT
);

CREATE FUNCTION pglog.log() RETURNS trigger AS $$
       """Logs all changes to a table, updating the pglog.Logs table.
       """
       
       # keep the prepared statement in memory
       if SD.has_key("plan"):
          plan = SD["plan"]
       else:
          plan = plpy.prepare("""
          INSERT INTO pglog.Logs (date, tablename, event, oldrow, newrow) 
          VALUES (now(), $1, $2, $3, $4)""", 
          ["text"] * 4)
          
          SD["plan"] = plan

       table = TD["args"][0]
       event = TD["event"]
       # XXX we have a dict instead of a tuple
       old = TD["old"] or {}
       new = TD["new"] or {}
       
       plpy.execute(plan, [table, event, old, new])
       plpy.execute("NOTIFY pglog")
$$ EXTERNAL SECURITY DEFINER LANGUAGE plpythonu;

CREATE FUNCTION pglog.enable_log(text) RETURNS text AS $$
       """Convenience function, used to enable logs to the 
       given table.
       """
       
       table = args[0]
       
       plpy.execute("""
       CREATE TRIGGER pglog_trigger AFTER INSERT OR UPDATE OR DELETE
       ON %(table)s FOR EACH ROW
       EXECUTE PROCEDURE pglog.log('%(table)s')""" % {"table": table})
$$ LANGUAGE plpythonu;


-- setup privileges
-- XXX TODO use roles? (only availables from 8.1)
CREATE GROUP loggers;

GRANT USAGE ON SCHEMA pglog TO PUBLIC;
GRANT SELECT ON TABLE pglog.Logs TO PUBLIC;
GRANT DELETE ON TABLE pglog.Logs TO GROUP loggers;
