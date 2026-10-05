-- =============================================================================
-- ESQUEMA DE BASE DE DATOS RELACIONAL - PROYECTO PASAKI
-- Plataforma: SQLite / Compatible ANSI SQL para Enterprise Architect (EA)
-- =============================================================================

DROP TABLE IF EXISTS movimientos;
DROP TABLE IF EXISTS garantias_prendarias;
DROP TABLE IF EXISTS prestamos;
DROP TABLE IF EXISTS garantes;
DROP TABLE IF EXISTS contactos;
DROP TABLE IF EXISTS clientes;

-- 1. TABLA: Clientes (Deudores principales)
CREATE TABLE clientes (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    nombre VARCHAR(100) NOT NULL,
    apellido VARCHAR(100),
    alias VARCHAR(100),
    ci VARCHAR(25),
    telefono_principal VARCHAR(25) NOT NULL,
    direccion TEXT,
    genero VARCHAR(20),
    fecha_nacimiento BIGINT,
    ingreso_mensual_cents BIGINT,
    es_lista_negra INTEGER NOT NULL DEFAULT 0,
    created_at BIGINT NOT NULL,
    updated_at BIGINT NOT NULL
);

CREATE INDEX idx_clientes_busqueda ON clientes(nombre, alias, telefono_principal);

-- 2. TABLA: Contactos (Teléfonos adicionales con parentesco / etiqueta)
CREATE TABLE contactos (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    cliente_id INTEGER NOT NULL,
    telefono VARCHAR(25) NOT NULL,
    etiqueta VARCHAR(50),
    created_at BIGINT NOT NULL,
    updated_at BIGINT NOT NULL,
    CONSTRAINT fk_contactos_cliente FOREIGN KEY (cliente_id) 
        REFERENCES clientes(id) ON DELETE CASCADE
);

CREATE INDEX idx_contactos_cliente ON contactos(cliente_id);

-- 3. TABLA: Garantes (Garantía Social entre personas)
CREATE TABLE garantes (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    deudor_id INTEGER NOT NULL,
    garante_cliente_id INTEGER NOT NULL,
    relacion VARCHAR(100),
    created_at BIGINT NOT NULL,
    CONSTRAINT fk_garantes_deudor FOREIGN KEY (deudor_id) 
        REFERENCES clientes(id) ON DELETE CASCADE,
    CONSTRAINT fk_garantes_garante FOREIGN KEY (garante_cliente_id) 
        REFERENCES clientes(id) ON DELETE RESTRICT
);

-- 4. TABLA: Préstamos (Contratos y condiciones financieras)
CREATE TABLE prestamos (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    cliente_id INTEGER NOT NULL,
    capital_inicial_cents BIGINT NOT NULL,
    tasa_porcentaje DECIMAL(5,2) NOT NULL,
    tasa_periodo VARCHAR(20) NOT NULL,
    modalidad VARCHAR(20) NOT NULL,
    saldo_capital_cents BIGINT NOT NULL,
    saldo_interes_cents BIGINT NOT NULL,
    estado VARCHAR(20) NOT NULL DEFAULT 'activo',
    fecha_inicio BIGINT NOT NULL,
    created_at BIGINT NOT NULL,
    updated_at BIGINT NOT NULL,
    CONSTRAINT fk_prestamos_cliente FOREIGN KEY (cliente_id) 
        REFERENCES clientes(id) ON DELETE RESTRICT
);

CREATE INDEX idx_prestamos_cliente ON prestamos(cliente_id);
CREATE INDEX idx_prestamos_estado ON prestamos(estado);

-- 5. TABLA: Garantías Prendarias (Respaldo físico / prendario)
CREATE TABLE garantias_prendarias (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    prestamo_id INTEGER NOT NULL,
    descripcion VARCHAR(255) NOT NULL,
    estado VARCHAR(30) NOT NULL DEFAULT 'pendiente',
    created_at BIGINT NOT NULL,
    updated_at BIGINT NOT NULL,
    CONSTRAINT fk_garantias_prestamo FOREIGN KEY (prestamo_id) 
        REFERENCES prestamos(id) ON DELETE CASCADE
);

CREATE INDEX idx_garantias_prestamo ON garantias_prendarias(prestamo_id);

-- 6. TABLA: Movimientos (Libro diario inalterable / Ledger contable)
CREATE TABLE movimientos (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    prestamo_id INTEGER NOT NULL,
    fecha BIGINT NOT NULL,
    tipo VARCHAR(50) NOT NULL,
    detalle VARCHAR(255) NOT NULL,
    debe_cents BIGINT,
    haber_cents BIGINT,
    saldo_capital_cents BIGINT NOT NULL,
    saldo_interes_cents BIGINT NOT NULL,
    created_at BIGINT NOT NULL,
    CONSTRAINT fk_movimientos_prestamo FOREIGN KEY (prestamo_id) 
        REFERENCES prestamos(id) ON DELETE CASCADE
);

CREATE INDEX idx_movimientos_prestamo ON movimientos(prestamo_id, fecha);
