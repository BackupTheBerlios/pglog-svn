/* 
pglog: enable logs on a PostgreSQL database.

$Id$

THIS SOFTWARE IS UNDER MIT LICENSE.
(C) 2006 Perillo Manlio (manlio.perillo@gmail.com)

Read LICENSE file for more informations.
*/


-- uninstall pglog
DROP SCHEMA pglog CASCADE;
DROP GROUP logger;
