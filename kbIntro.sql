/*
	Bases de Datos (Laboratorio).
	Prof: Asistente de Cátedra, Hisakazu Ishibashi.
	Ingeniería Informática - Universidad Nacional de Itapúa (UNI)
	Licencia: Creative Commons 2012
	
	UNI Knowledge Base
	
	Es una aplicación web para compartir conocimiento a través de enlaces (URLs) visitados
	por los alumnos registrados en la base de datos, y está desarrollado en el marco de las 
	clases de laboratorio de la materia Bases de Datos.
	
	Este script contiene el historial de los comandos TransactSQL (SQL Server 2008 R2) utilizados para crear 
	la BD de la aplicación. El origen de esta BD es la disseñada en la clase del 20/03/2012, la cual tenía 
	originalmente una tabla dbo.Alumno y otra dbo.Email. dbo es el schema por defecto en SQL Server.
	
	Los nombres de tablas y campos de ésta BD se escribirán acorde a lo convencional en Ruby on Rails. 
	
	Observación: 
	1) Una limitacion del Transact-SQL o T-SQL es que no se pueden utilizar variables como nombre 
	de tablas o de bases de datos, por lo cual si se quiere "Parametrizar", osea crear SQL dinámicamente (dsql),
	hay que usar la sentencia EXECUTE.
	
	2) El script a continuación es a modo de ejemplo para que los alumnos conozcan algunas cosas de T-SQL. En realidad
	pudo haber sido todo mucho más simple. 
*/

-- Declarar e inicializar los parametros de este script.
USE AlumnosUNI;
DECLARE @DB_NAME VARCHAR(128) = 'uni_kb_dev';
DECLARE @OLD_DB_NAME VARCHAR(128) = DB_NAME(); -- Devuelve el nombre que se puso en la proposicion USE
DECLARE @LOGIN_NAME VARCHAR(128) = 'uni';
DECLARE @USER_NAME VARCHAR(128) = @LOGIN_NAME;
DECLARE @LOGIN_PASSWD VARCHAR(128) = 's3cr3t0';
DECLARE @LOGIN_DEF_SCHEMA VARCHAR(128) = 'Personas';
DECLARE @DB_ROLE VARCHAR(128) = 'db_owner';	-- Utilizar este role para que el usuario a ser creado tenga todos los privilegios sobre la BD
DECLARE @DB_DDL VARCHAR(512) = '
		ALTER DATABASE {OLD_DB_NAME} SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
		ALTER DATABASE {OLD_DB_NAME} MODIFY NAME = {DB_NAME};
		ALTER DATABASE {DB_NAME} SET MULTI_USER';
		
DECLARE @USER_SQL VARCHAR(512) = '
		CREATE LOGIN {LOGIN_NAME} WITH PASSWORD = ''{LOGIN_PASSWD}'';
		CREATE USER {USER_NAME} FOR LOGIN {LOGIN_NAME} WITH DEFAULT_SCHEMA = {LOGIN_DEF_SCHEMA};';

-- Detener la ejecucion si no estamos conectados a la @OLD_BD_NAME
IF DB_NAME() != @OLD_DB_NAME 
	BEGIN
		print 'Error Fatal, No se pudo conectar a la base de datos '+ @OLD_DB_NAME;
		set noexec on;
	END
ELSE -- Cambiar el nombre de la BD	
	BEGIN
		SET @DB_DDL = REPLACE(@DB_DDL,'{OLD_DB_NAME}', @OLD_DB_NAME);
		SET @DB_DDL = REPLACE(@DB_DDL,'{DB_NAME}', @DB_NAME);
		EXEC (@DB_DDL);		 	
	END

-- Detener la ejecucion si no estamos conectados a la @DB_NAME
IF DB_NAME() != @DB_NAME 
	BEGIN
		print 'Error Fatal, No se pudo conectar a la base de datos '+ @DB_NAME;
		set noexec on;
	END
ELSE
-- En este punto ya estamos en la BD con el nuevo nombre. Seria lo mismo que haber hecho USE @DB_NAME si se pudiera	
	print 'El nombre de la BD ha sido cambiado a '+@DB_NAME+' de manera existosa'
	
-- Intentar crear LOGIN y USER para trabajar con la BD
SET @USER_SQL = REPLACE(@USER_SQL,'{LOGIN_NAME}', @LOGIN_NAME);
SET @USER_SQL = REPLACE(@USER_SQL,'{LOGIN_PASSWD}', @LOGIN_PASSWD);
SET @USER_SQL = REPLACE(@USER_SQL,'{USER_NAME}', @USER_NAME);
SET @USER_SQL = REPLACE(@USER_SQL,'{LOGIN_DEF_SCHEMA}', @LOGIN_DEF_SCHEMA);
EXEC (@USER_SQL);

-- Verificar si el Login y su respectivo User en la BD actual pudieron ser creados
IF 
	NOT EXISTS(SELECT name FROM sys.database_principals WHERE name = @LOGIN_NAME) 
	OR 
	NOT EXISTS(SELECT name FROM sys.server_principals WHERE name = @USER_NAME)
	BEGIN
		print 'Error Fatal, fallo la creacion de Login y User';
		set noexec on;		
	END
ELSE
	BEGIN
		EXEC sp_addrolemember @DB_ROLE, @USER_NAME	-- Agregar el usuario al role db_owner
		-- Lo de abajo se pudo haber hecho al con CREATE LOGIN login_name WITH PASSWORD='passwd', WITH DEFAULT_DATABASE='bd'
		-- Pero es bueno mostrar que hay un Stored Procedure para asignar una BD por defecto a un login.
		EXEC sp_defaultdb @LOGIN_NAME, @DB_NAME 
	END


-- Consultar cuales son los permisos del "principal" recientemente creado.
-- Solo aparece CONNECT debido a que los permisos fueron otorgados a traves del rol db_owner.
SELECT
dp.class_desc, dp.permission_name, dp.state_desc,
ObjectName = OBJECT_NAME(major_id), GranteeName = grantee.name, GrantorName = grantor.name
FROM sys.database_permissions dp
JOIN sys.database_principals grantee on dp.grantee_principal_id = grantee.principal_id
JOIN sys.database_principals grantor on dp.grantor_principal_id = grantor.principal_id
WHERE grantee.name = @USER_NAME;

-- Consultar sobre los roles a los que pertenece el user uni en la base de datos actual
exec sp_helpuser @name_in_db = @USER_NAME;

-- Consultar los usuarios que tienen el rol @DB_ROLE en la base de datos actual
exec sp_helpuser @name_in_db = @DB_ROLE;

-- Consultar informacion acerca de los logins y los usuarios asociados a los mismos en cada base de datos
exec sp_helplogins @LoginNamePattern = @LOGIN_NAME;

/*
	Necesitamos este GO aqui para que el servidor procese todos los cambios anteriores. Sin el GO, todos los cambios se pierden
	al cambiar de contexto.
	Pero como el GO delimita el alcance de las variables decladas, necesitamos guardarlas de alguna manera para poder obtenerlas
	devuelta despues del GO, y tambien dentro del contexto al que se cambia cuando se ejecuta EXEC AS LOGIN. Para tal efecto
	crearemos una tabla temporal en donde almacenaremos los datos que necesitaremos de aqui en adelante.
*/

create table tmp_variables(
	login_name varchar(128),
	user_name varchar(128)
);
insert into tmp_variables values(@LOGIN_NAME, @USER_NAME);
GO 
-- Recuerden que no estamos redeclarando debido al GO que se encuentra justo en la linea de arriba
DECLARE @LOGIN_NAME VARCHAR(128);
SELECT TOP 1 @LOGIN_NAME = login_name FROM tmp_variables;
-- Probar si el User creado puede ejecutar el DDL
EXEC AS LOGIN = @LOGIN_NAME;

-- Al inicio solo existia el schema dbo y las tablas dbo.Alumno y dbo.Email
IF schema_id('dbo') is null AND OBJECT_ID('Alumno') is null OR OBJECT_ID('Email') is null 
BEGIN
	PRINT 'Error Fatal, El schema Person existe pero las tablas dbo.Alumno y dbo.Email no'
	set noexec on
END 

/**
	Agregamos la columna email a la tabla Alumno.
	ATENCION!!: Solo se pueden agregar con ALTER table columnas que acepten NULL o que tengan un valor por DEFAULT.
	Despues de copiar todos los datos de la tabla Email a la tabla Alumnos haremos que esta columna sea NOT NULL.
*/
ALTER TABLE Alumno ADD email varchar(128)NULL;
GO

-- Verificar si la columna email ha sido creada correctamente
IF COL_LENGTH('Alumno', 'email') is null
	BEGIN
		PRINT 'Error Fatal, no se pudo crear la columna email en la tabla Alumno'
		set noexec on
	END
ELSE
	BEGIN
		PRINT 'Se ha agregado la columna email a la tabla Alumno'
		-- Copiar la columna email de la tabla Email a la tabla Alumno.
		-- Lo hacemos dentro del bloque BEGIN...END dentro del ELSE debido a que NOEXEC ON solo sirve para DDL
		UPDATE Alumno set Alumno.email = Email.email from Alumno INNER JOIN Email on Alumno.cedula = Email.cedula;
		ALTER TABLE Alumno ALTER COLUMN email VARCHAR(128) NOT NULL;
		ALTER TABLE Alumno ADD CONSTRAINT email_unique UNIQUE(email);
		
/**		
		Ahora que tenemos los datos de Alumno y Email juntos en una tabla necesitamos agregar un PK llamado id para trabajar con RoR.
		Como SQL Server no deja agregar una nueva columna en un lugar especifico lo que hay que hacer lo sgt:
		1) Crear una tabla tmp_alumno con las columnas ordenadas de la forma requerida
		2) Copiar los datos de la tabla Alumno a la tmp_alumno
		3) Borrar la tabla Alumno
		4) Cambiar el nombre de la tabla tmp_alumno a Alumno, pero nosotros usaremos el nombre Usuarios
		
		De acuerdo a la convencion de ActiveRecord de RoR "Models in Rails use a singular name, and their corresponding DB tables use a plural name."
		Ver: http://tinyurl.com/d8kmsj
*/
		PRINT 'Creando tabla tmp_alumno';
		CREATE TABLE dbo.tmp_alumno(
			id int primary key not null identity(1,1),
			nombre varchar(128) not null,
			apellido varchar(128) not null,
			docId varchar(128) not null CONSTRAINT uq_doc_alum UNIQUE,
			email varchar(128) not null CONSTRAINT uq_email_alum UNIQUE
		);
		PRINT 'Copiando los datos de la tabla Alumno a la tabla tmp_alumno';
		INSERT INTO dbo.tmp_alumno(nombre, apellido, docId, email) SELECT nombre, apellido, cedula, email FROM dbo.Alumno;
		PRINT 'Cambiando el nombre de la tabla tmp_alumno a Usuarios'
		-- Podiamos haber creado directamente la tabla Usuarios en vez de tmp_alumno pero queria mostrar el Procedimiento Almacenado sp_rename
		EXEC sp_rename 'tmp_alumno', 'usuarios'
		/**
			Para eliminar la tabla Alumno primero hay que eliminar la FK asociada a este. Podriamos haber eliminado la tabla Email pero 
			a modo de ejemplo, buscamos y eliminamos dinamicamente las FKs.
		*/
		PRINT 'Eliminando referencias a la tabla dbo.Alumno'
		DECLARE @tableName varchar(128);
		DECLARE @refName varchar(128);
		DECLARE @dropFkSql varchar(128) = 'ALTER TABLE {tableName} DROP CONSTRAINT {refName};'
		DECLARE refAlumnoCursor CURSOR FAST_FORWARD
		FOR
			Select
				object_name(fkeyid) Child_Table,
				object_name(constid) FKey_Name
			From
				sys.sysforeignkeys s
				Inner join sys.syscolumns c1
				on ( s.fkeyid = c1.id And s.fkey = c1.colid )
				Inner join syscolumns c2
				on ( s.rkeyid = c2.id And s.rkey = c2.colid )

		OPEN refAlumnoCursor
		FETCH NEXT FROM refAlumnoCursor INTO @tableName, @refName
		WHILE @@FETCH_STATUS = 0
		BEGIN
			SET @dropFkSql = REPLACE(@dropFkSql,'{tableName}', @tableName);
			SET @dropFkSql = REPLACE(@dropFkSql,'{refName}', @refName);
			EXEC (@dropFkSql);
			FETCH NEXT FROM refAlumnoCursor INTO @tableName, @refName
		END
		CLOSE refAlumnoCursor
		DEALLOCATE refAlumnoCursor
		PRINT 'Eliminando la tabla Alumno'
		DROP TABLE dbo.Alumno;
	END	

-- Verificar si se pudo cambiar el nombre de la tabla Alumno a Usuarios
IF OBJECT_ID('Usuarios') is null
	BEGIN
		PRINT 'Error Fatal, no se pudo cambiar el nombre de la tabla Alumno a Usuarios y no se puede continuar'
		set noexec on
	END
ELSE
	PRINT 'El nombre de la tabla Alumno ha sido cambiado a Usuarios'

-- Destruir la tabla Email
DROP TABLE dbo.Email;

IF OBJECT_ID('dbo.Email') is null
	PRINT 'La tabla Email ha sido eliminada satisfactoriamente'
ELSE
	PRINT 'Error, No se pudo eliminar la tabla Email'

DECLARE @USER_NAME VARCHAR(128);
SELECT TOP 1 @USER_NAME = user_name FROM tmp_variables

-- Crear el schema Personas
EXEC('CREATE SCHEMA Personas AUTHORIZATION '+@USER_NAME);
IF schema_id('Personas') is null
BEGIN
	PRINT 'Error Fatal, No se pudo crear el SCHEMA Personas, no se puede continuar'
	set noexec on
END
ELSE
	PRINT 'Se ha creado el SCHEMA Personas' 

-- Transferir la tabla al SCHEMA Personas
ALTER SCHEMA Personas TRANSFER dbo.Usuarios;

-- Destruir la tabla en donde guardamos las variables
DROP TABLE tmp_variables;

-- Volver al contexto de ejecucion anterior (empezamos con sa, cambiamos a @LOGIN_NAME y volvemos a sa)
REVERT;

-- ultima linea del archivo
set noexec off	-- volver a ejecutar la ejecucion de comandos en caso de haber sido desactivada.
GO -- Señalizar el fin de este archivo de ejecución por lotes