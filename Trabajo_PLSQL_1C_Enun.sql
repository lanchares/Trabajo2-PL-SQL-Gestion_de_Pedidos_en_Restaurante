-- Enlace al repositorio github, esta hecho en la rama PLSQL, no en el main.
-- https://github.com/lanchares/Trabajo2-PL-SQL-Gestion_de_Pedidos_en_Restaurante/tree/PLSQL

DROP TABLE detalle_pedido CASCADE CONSTRAINTS;
DROP TABLE pedidos CASCADE CONSTRAINTS;
DROP TABLE platos CASCADE CONSTRAINTS;
DROP TABLE personal_servicio CASCADE CONSTRAINTS;
DROP TABLE clientes CASCADE CONSTRAINTS;

DROP SEQUENCE seq_pedidos;

-- Creación de tablas y secuencias
create sequence seq_pedidos;

CREATE TABLE clientes (
    id_cliente INTEGER PRIMARY KEY,
    nombre VARCHAR2(100) NOT NULL,
    apellido VARCHAR2(100) NOT NULL,
    telefono VARCHAR2(20)
);

CREATE TABLE personal_servicio (
    id_personal INTEGER PRIMARY KEY,
    nombre VARCHAR2(100) NOT NULL,
    apellido VARCHAR2(100) NOT NULL,
    pedidos_activos INTEGER DEFAULT 0 CHECK (pedidos_activos <= 5)
);

CREATE TABLE platos (
    id_plato INTEGER PRIMARY KEY,
    nombre VARCHAR2(100) NOT NULL,
    precio DECIMAL(10, 2) NOT NULL,
    disponible INTEGER DEFAULT 1 CHECK (DISPONIBLE in (0,1))
);

CREATE TABLE pedidos (
    id_pedido INTEGER PRIMARY KEY,
    id_cliente INTEGER REFERENCES clientes(id_cliente),
    id_personal INTEGER REFERENCES personal_servicio(id_personal),
    fecha_pedido DATE DEFAULT SYSDATE,
    total DECIMAL(10, 2) DEFAULT 0
);

CREATE TABLE detalle_pedido (
    id_pedido INTEGER REFERENCES pedidos(id_pedido),
    id_plato INTEGER REFERENCES platos(id_plato),
    cantidad INTEGER NOT NULL,
    PRIMARY KEY (id_pedido, id_plato)
);
	
-- Procedimiento para realizar la reserva
create or replace procedure registrar_pedido(
    arg_id_cliente      INTEGER, 
    arg_id_personal     INTEGER, 
    arg_id_primer_plato INTEGER DEFAULT NULL,
    arg_id_segundo_plato INTEGER DEFAULT NULL
) is 
    v_pedidos_activos INTEGER;           -- Almacena el número de pedidos activos del personal
    v_disponible_primer_plato INTEGER;   -- Indica si el primer plato está disponible (1) o no (0)
    v_disponible_segundo_plato INTEGER;  -- Indica si el segundo plato está disponible (1) o no (0)
    v_precio_primer_plato DECIMAL(10,2); -- Almacena el precio del primer plato
    v_precio_segundo_plato DECIMAL(10,2);-- Almacena el precio del segundo plato
    v_total DECIMAL(10,2) := 0;          -- Acumula el precio total del pedido
    v_nuevo_id_pedido INTEGER;           -- Guarda el ID generado para el nuevo pedido
    v_existe_primer_plato INTEGER := 0;  -- Verifica si el primer plato existe en la BD
    v_existe_segundo_plato INTEGER := 0; -- Verifica si el segundo plato existe en la BD

BEGIN
    -- Comprobar que el pedido contiene al menos un plato
    IF arg_id_primer_plato IS NULL AND arg_id_segundo_plato IS NULL THEN
        RAISE_APPLICATION_ERROR(-20002, 'El pedido debe contener al menos un plato.');
    END IF;
    
    -- Comprobar que los platos existen y están disponibles
    -- Verificar primer plato si se ha solicitado
    IF arg_id_primer_plato IS NOT NULL THEN
        -- Verificar si el plato existe
        SELECT COUNT(*) INTO v_existe_primer_plato 
        FROM platos 
        WHERE id_plato = arg_id_primer_plato;
        
        IF v_existe_primer_plato = 0 THEN
            RAISE_APPLICATION_ERROR(-20004, 'El primer plato seleccionado no existe');
        END IF;
        
        -- Verificar si el plato está disponible
        SELECT disponible, precio INTO v_disponible_primer_plato, v_precio_primer_plato 
        FROM platos 
        WHERE id_plato = arg_id_primer_plato;
        
        IF v_disponible_primer_plato = 0 THEN
            RAISE_APPLICATION_ERROR(-20001, 'Uno de los platos seleccionados no está disponible.');
        END IF;
        
        v_total := v_total + v_precio_primer_plato;
    END IF;
    
    -- Verificar segundo plato si se ha solicitado
    IF arg_id_segundo_plato IS NOT NULL THEN
        -- Verificar si el plato existe
        SELECT COUNT(*) INTO v_existe_segundo_plato 
        FROM platos 
        WHERE id_plato = arg_id_segundo_plato;
        
        IF v_existe_segundo_plato = 0 THEN
            RAISE_APPLICATION_ERROR(-20004, 'El segundo plato seleccionado no existe');
        END IF;
        
        -- Verificar si el plato está disponible
        SELECT disponible, precio INTO v_disponible_segundo_plato, v_precio_segundo_plato 
        FROM platos 
        WHERE id_plato = arg_id_segundo_plato;
        
        IF v_disponible_segundo_plato = 0 THEN
            RAISE_APPLICATION_ERROR(-20001, 'Uno de los platos seleccionados no está disponible.');
        END IF;
        
        v_total := v_total + v_precio_segundo_plato;
    END IF;
    
    -- Comprobar que el personal de servicio puede atender más pedidos
    SELECT pedidos_activos INTO v_pedidos_activos 
    FROM personal_servicio 
    WHERE id_personal = arg_id_personal 
    FOR UPDATE; -- Bloqueo para evitar condiciones de carrera
    
    IF v_pedidos_activos >= 5 THEN
        RAISE_APPLICATION_ERROR(-20003, 'El personal de servicio tiene demasiados pedidos.');
    END IF;
    
    -- Añadir el pedido a la tabla pedidos
    SELECT seq_pedidos.NEXTVAL INTO v_nuevo_id_pedido FROM dual;
    
    INSERT INTO pedidos (id_pedido, id_cliente, id_personal, fecha_pedido, total)
    VALUES (v_nuevo_id_pedido, arg_id_cliente, arg_id_personal, SYSDATE, v_total);
    
    -- Añadir los detalles de pedido a la tabla detalle_pedido
    IF arg_id_primer_plato IS NOT NULL THEN
        INSERT INTO detalle_pedido (id_pedido, id_plato, cantidad)
        VALUES (v_nuevo_id_pedido, arg_id_primer_plato, 1);
    END IF;
    
    IF arg_id_segundo_plato IS NOT NULL THEN
        INSERT INTO detalle_pedido (id_pedido, id_plato, cantidad)
        VALUES (v_nuevo_id_pedido, arg_id_segundo_plato, 1);
    END IF;
    
    -- Actualizar la tabla de personal_servicio
    UPDATE personal_servicio
    SET pedidos_activos = pedidos_activos + 1
    WHERE id_personal = arg_id_personal;
    
    -- Confirmar transacción
    COMMIT;
    
EXCEPTION
    WHEN OTHERS THEN
        -- Deshacer cambios en caso de error
        ROLLBACK;
        -- Relanzar la excepción
        RAISE;
END;
/

------ Deja aquí tus respuestas a las preguntas del enunciado:
-- NO SE CORREGIRÁN RESPUESTAS QUE NO ESTÉN AQUÍ (utiliza el espacio que necesites apra cada una)
	
-- * P4.1
	
-- Garantizo que un miembro del personal de servicio no supere el límite de pedidos activos verificando la columna pedidos_activos en la tabla personal_servicio antes de asignar un nuevo pedido. Si el número de pedidos activos ya es 5 o más, se lanza un error y se aborta la operación.
	
-- * P4.2
	
-- Para evitar que dos transacciones concurrentes asignen un pedido al mismo personal de servicio cuando sus pedidos activos están cerca del límite, utilizo una cláusula FOR UPDATE en la consulta que obtiene pedidos_activos. Esto bloquea la fila correspondiente en la tabla personal_servicio, impidiendo que otra transacción la modifique hasta que la actual finalice (ya sea con COMMIT o ROLLBACK).
	
-- * P4.3
	
--  Sí, puedo asegurar que el pedido se realiza de manera correcta en el paso 4 y que no se generan inconsistencias porque:

		-- Bloqueo de la fila de personal_servicio: Se evita que otro proceso modifique el número de pedidos activos antes de que termine la transacción.

		-- Verificación de la disponibilidad de los platos: Antes de insertar el pedido, se comprueba que los platos existen y están disponibles.

		-- Transacción atómica: Todo el proceso (inserción del pedido, actualización de personal_servicio y detalle_pedido) se ejecuta dentro de una única transacción. Si ocurre un error en cualquier parte, se ejecuta un ROLLBACK, evitando inconsistencias en la base de datos.
	
-- * P4.4
	
-- Si añadiéramos CHECK (pedidos_activos ≤ 5) en la tabla personal_servicio, habría implicaciones en la gestión de excepciones:

	-- No sería suficiente para evitar condiciones de carrera: El CHECK solo impide valores inválidos en la columna, pero no previene la posibilidad de que dos transacciones concurrentes lean el mismo valor y ambas intenten aumentar pedidos_activos a un valor mayor a 5 antes de que se valide la restricción.
-- Se generarían errores de integridad en vez de errores controlados: En lugar de lanzar un error específico (RAISE_APPLICATION_ERROR(-20003, 'El personal de servicio tiene demasiados pedidos.')), la base de datos lanzaría un error genérico de restricción de CHECK, lo que dificultaría el control en el procedimiento.

-- Para solucionar esto, debería:
	-- Mantener el FOR UPDATE para evitar condiciones de carrera.
	-- Capturar la excepción de CHECK y traducirla a un mensaje más claro antes de propagarla.
	-- Asegurarme de que la lógica en el procedimiento sigue verificando pedidos_activos antes de actualizarlo, en lugar de confiar únicamente en la restricción CHECK.

	
-- * P4.5
	
-- La estrategia de programación utilizada es programación defensiva y control de concurrencia.

-- Programación Defensiva
-- Se verifica activamente que los datos sean válidos antes de realizar cualquier modificación en la base de datos. Esto se ve en:
-- La comprobación de que pedidos_activos < 5 antes de asignar un nuevo pedido.
-- La validación de la disponibilidad de los platos antes de insertarlos en detalle_pedido
-- El manejo explícito de errores mediante excepciones (RAISE_APPLICATION_ERROR) para evitar inconsistencias.

-- Control de Concurrencia
-- Se usa SELECT ... FOR UPDATE para bloquear la fila de personal_servicio y evitar condiciones de carrera cuando varias transacciones intentan asignar pedidos al mismo miembro del personal simultáneamente.

-- Estas estrategias se reflejan en el código en las secciones donde se validan los límites de pedidos_activos, se bloquean registros con FOR UPDATE y se capturan excepciones para garantizar la coherencia de los datos.


create or replace
procedure reset_seq( p_seq_name varchar )
is
    l_val number;
begin
    execute immediate
    'select ' || p_seq_name || '.nextval from dual' INTO l_val;

    execute immediate
    'alter sequence ' || p_seq_name || ' increment by -' || l_val || 
                                                          ' minvalue 0';
    execute immediate
    'select ' || p_seq_name || '.nextval from dual' INTO l_val;

    execute immediate
    'alter sequence ' || p_seq_name || ' increment by 1 minvalue 0';

end;
/


create or replace procedure inicializa_test is
begin
    
    reset_seq('seq_pedidos');
        
  
    delete from Detalle_pedido;
    delete from Pedidos;
    delete from Platos;
    delete from Personal_servicio;
    delete from Clientes;
    
    -- Insertar datos de prueba
    insert into Clientes (id_cliente, nombre, apellido, telefono) values (1, 'Pepe', 'Perez', '123456789');
    insert into Clientes (id_cliente, nombre, apellido, telefono) values (2, 'Ana', 'Garcia', '987654321');
    
    insert into Personal_servicio (id_personal, nombre, apellido, pedidos_activos) values (1, 'Carlos', 'Lopez', 0);
    insert into Personal_servicio (id_personal, nombre, apellido, pedidos_activos) values (2, 'Maria', 'Fernandez', 5);
    
    insert into Platos (id_plato, nombre, precio, disponible) values (1, 'Sopa', 10.0, 1);
    insert into Platos (id_plato, nombre, precio, disponible) values (2, 'Pasta', 12.0, 1);
    insert into Platos (id_plato, nombre, precio, disponible) values (3, 'Carne', 15.0, 0);

    commit;
end;
/

exec inicializa_test;


create or replace procedure test_registrar_pedido is
begin
    -- Caso 1: Pedido correcto.
    BEGIN
        inicializa_test;
        DBMS_OUTPUT.PUT_LINE('Test 1: Pedido correcto con primer plato o segundo');
        registrar_pedido(1, 1, 1, NULL);
        registrar_pedido(2, 1, NULL, 1);
        DBMS_OUTPUT.PUT_LINE('Test 1: OK - Pedido registrado correctamente');
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Test 1: ERROR - ' || SQLERRM);
    END;
    
    -- Caso 2: Pedido correcto con dos platos
    BEGIN
        inicializa_test;
        DBMS_OUTPUT.PUT_LINE('Test 2: Pedido correcto con dos platos');
        registrar_pedido(1, 1, 1, 2);
        DBMS_OUTPUT.PUT_LINE('Test 2: OK - Pedido con dos platos registrado correctamente');
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Test 2: ERROR - ' || SQLERRM);
    END;
    
    -- Caso 3: Pedido vacío (sin platos)
    BEGIN
        inicializa_test;
        DBMS_OUTPUT.PUT_LINE('Test 3: Pedido vacío (sin platos)');
        registrar_pedido(1, 1, NULL, NULL);
        DBMS_OUTPUT.PUT_LINE('Test 3: ERROR - No se lanzó la excepción esperada');
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE = -20002 THEN
                DBMS_OUTPUT.PUT_LINE('Test 3: OK - ' || SQLERRM);
            ELSE
                DBMS_OUTPUT.PUT_LINE('Test 3: ERROR - Excepción incorrecta: ' || SQLERRM);
            END IF;
    END;
    
    -- Caso 4: Pedido con plato que no existe
    BEGIN
        inicializa_test;
        DBMS_OUTPUT.PUT_LINE('Test 4: Pedido con plato inexistente');
        registrar_pedido(1, 1, 99, NULL);
        DBMS_OUTPUT.PUT_LINE('Test 4: ERROR - No se lanzó la excepción esperada');
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE = -20004 THEN
                DBMS_OUTPUT.PUT_LINE('Test 4: OK - ' || SQLERRM);
            ELSE
                DBMS_OUTPUT.PUT_LINE('Test 4: ERROR - Excepción incorrecta: ' || SQLERRM);
            END IF;
    END;
    
    -- Caso 5: Pedido con plato no disponible
    BEGIN
        inicializa_test;
        DBMS_OUTPUT.PUT_LINE('Test 5: Pedido con plato no disponible');
        registrar_pedido(1, 1, 3, NULL);
        DBMS_OUTPUT.PUT_LINE('Test 5: ERROR - No se lanzó la excepción esperada');
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE = -20001 THEN
                DBMS_OUTPUT.PUT_LINE('Test 5: OK - ' || SQLERRM);
            ELSE
                DBMS_OUTPUT.PUT_LINE('Test 5: ERROR - Excepción incorrecta: ' || SQLERRM);
            END IF;
    END;
    
    -- Caso 6: Personal con demasiados pedidos activos
    BEGIN
        inicializa_test;
        DBMS_OUTPUT.PUT_LINE('Test 6: Personal con demasiados pedidos');
        registrar_pedido(1, 2, 1, NULL); -- María tiene 5 pedidos activos
        DBMS_OUTPUT.PUT_LINE('Test 6: ERROR - No se lanzó la excepción esperada');
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE = -20003 THEN
                DBMS_OUTPUT.PUT_LINE('Test 6: OK - ' || SQLERRM);
            ELSE
                DBMS_OUTPUT.PUT_LINE('Test 6: ERROR - Excepción incorrecta: ' || SQLERRM);
            END IF;
    END;
END;
/

set serveroutput on;
exec test_registrar_pedido;
