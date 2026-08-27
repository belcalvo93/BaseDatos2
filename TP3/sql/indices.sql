-- Indices creados en la Parte 2, uno por vez, midiendo antes y despues.
-- Mediciones y justificacion en TP3/bitacora_mediciones.md

CREATE INDEX idx_pedido_usuario ON pedido(usuario_id);
CREATE INDEX idx_producto_categoria ON producto(categoria_id);
CREATE INDEX idx_pedido_fecha ON pedido(fecha);
