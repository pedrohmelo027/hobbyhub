-- HH - Massa de Testes
-- SpinOff: scripts SQL com dados consistentes com os cenários do Roteiro de Testes.
-- Uso exclusivo no banco isolado hobbyhub_teste. Não execute no banco de apresentação/produção.
-- Pré-requisito: crie o banco hobbyhub_teste e inicie o backend uma vez apontando
-- MYSQL_URL para ele, para o Hibernate criar as tabelas. Depois execute este arquivo.
-- A instrução CREATE DATABASE abaixo pode ser executada sozinha antes de iniciar o backend.
-- Contas: ana.teste@example.invalid / Ficticia-01-NaoReutilizar
--         bruno.teste@example.invalid / Ficticia-02-NaoReutilizar
--         admin.teste@example.invalid / Ficticia-Admin-01-NaoReutilizar

CREATE DATABASE IF NOT EXISTS hobbyhub_teste
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;
USE hobbyhub_teste;

START TRANSACTION;

-- Contas comuns: Ana executa os cenários; Bruno é autor do post de terceiros.
INSERT INTO usuarios (nome, email, biografia, url_foto_perfil, nome_usuario, senha, `role`)
VALUES
  ('Ana Teste', 'ana.teste@example.invalid', 'Gosto de ciclismo.', NULL, 'ana_teste', '$2a$10$BtpPerJ2FtrQMFfyOPg1Eehtk/.vbM3XcfXryE5sj.dEqXr1t4cAm', 'USUARIO'),
  ('Bruno Teste', 'bruno.teste@example.invalid', 'Publicações de teste.', NULL, 'bruno_teste', '$2a$10$8bEvA7uPBbdLBIZZD.5Wdu9p1.AYKjiu9iAHxw5E/O55O5ldzg/Te', 'USUARIO'),
  ('Admin de Teste', 'admin.teste@example.invalid', 'Conta administrativa de teste.', NULL, 'admin_teste', '$2a$10$uD6zNcTzjpFLEDGWHoiLtOMYyDqxp.keQAerEM1z9bjkeiMvdF74q', 'ADMIN')
ON DUPLICATE KEY UPDATE
  nome = VALUES(nome),
  biografia = VALUES(biografia),
  url_foto_perfil = VALUES(url_foto_perfil),
  senha = VALUES(senha),
  `role` = VALUES(`role`);

SET @ana_id = (SELECT id FROM usuarios WHERE email = 'ana.teste@example.invalid' LIMIT 1);
SET @bruno_id = (SELECT id FROM usuarios WHERE email = 'bruno.teste@example.invalid' LIMIT 1);

-- Tags gerais e específicas usadas nos cenários com resultados e sem resultados.
INSERT INTO tags (nome, tipo, tag_geral_id)
VALUES ('Lazer', 'GERAL', NULL), ('Jogos', 'GERAL', NULL), ('Esporte', 'GERAL', NULL), ('Tag teste sem uso', 'GERAL', NULL)
ON DUPLICATE KEY UPDATE tag_geral_id = VALUES(tag_geral_id);

SET @lazer_id = (SELECT id FROM tags WHERE nome = 'Lazer' AND tipo = 'GERAL' LIMIT 1);
SET @jogos_id = (SELECT id FROM tags WHERE nome = 'Jogos' AND tipo = 'GERAL' LIMIT 1);
SET @esporte_id = (SELECT id FROM tags WHERE nome = 'Esporte' AND tipo = 'GERAL' LIMIT 1);

INSERT INTO tags (nome, tipo, tag_geral_id)
VALUES
  ('Ciclismo', 'ESPECIFICA', @lazer_id),
  ('Xadrez', 'ESPECIFICA', @jogos_id),
  ('Futebol', 'ESPECIFICA', @esporte_id)
ON DUPLICATE KEY UPDATE tag_geral_id = VALUES(tag_geral_id);

SET @ciclismo_id = (SELECT id FROM tags WHERE nome = 'Ciclismo' AND tipo = 'ESPECIFICA' LIMIT 1);
SET @xadrez_id = (SELECT id FROM tags WHERE nome = 'Xadrez' AND tipo = 'ESPECIFICA' LIMIT 1);
SET @futebol_id = (SELECT id FROM tags WHERE nome = 'Futebol' AND tipo = 'ESPECIFICA' LIMIT 1);

-- Ana acompanha Ciclismo. O teste de Xadrez deve retornar feed vazio.
INSERT INTO usuario_tags (usuario_id, tag_id)
SELECT @ana_id, @ciclismo_id
WHERE NOT EXISTS (
  SELECT 1 FROM usuario_tags WHERE usuario_id = @ana_id AND tag_id = @ciclismo_id
);

-- D15: post de Bruno. Ana não pode editá-lo; Admin pode removê-lo.
INSERT INTO posts (conteudo, data_criacao, url_imagem, usuario_id)
SELECT '[HH-MASSA-D15] Pedalei no parque com amigos.', '2026-11-01 10:00:00', NULL, @bruno_id
WHERE NOT EXISTS (
  SELECT 1 FROM posts WHERE conteudo = '[HH-MASSA-D15] Pedalei no parque com amigos.' AND usuario_id = @bruno_id
);
SET @post_d15_id = (
  SELECT id FROM posts WHERE conteudo = '[HH-MASSA-D15] Pedalei no parque com amigos.' AND usuario_id = @bruno_id LIMIT 1
);

-- D16: post próprio de Ana para cenário de edição.
INSERT INTO posts (conteudo, data_criacao, url_imagem, usuario_id)
SELECT '[HH-MASSA-D16] Pedalei no parque no fim de semana.', '2026-11-01 11:00:00', NULL, @ana_id
WHERE NOT EXISTS (
  SELECT 1 FROM posts WHERE conteudo = '[HH-MASSA-D16] Pedalei no parque no fim de semana.' AND usuario_id = @ana_id
);
SET @post_d16_id = (
  SELECT id FROM posts WHERE conteudo = '[HH-MASSA-D16] Pedalei no parque no fim de semana.' AND usuario_id = @ana_id LIMIT 1
);

-- Cada post recebe uma tag geral e uma específica, como exige a regra de domínio.
INSERT INTO post_tags (post_id, tag_id)
SELECT @post_d15_id, @lazer_id
WHERE NOT EXISTS (SELECT 1 FROM post_tags WHERE post_id = @post_d15_id AND tag_id = @lazer_id);
INSERT INTO post_tags (post_id, tag_id)
SELECT @post_d15_id, @ciclismo_id
WHERE NOT EXISTS (SELECT 1 FROM post_tags WHERE post_id = @post_d15_id AND tag_id = @ciclismo_id);
INSERT INTO post_tags (post_id, tag_id)
SELECT @post_d16_id, @lazer_id
WHERE NOT EXISTS (SELECT 1 FROM post_tags WHERE post_id = @post_d16_id AND tag_id = @lazer_id);
INSERT INTO post_tags (post_id, tag_id)
SELECT @post_d16_id, @ciclismo_id
WHERE NOT EXISTS (SELECT 1 FROM post_tags WHERE post_id = @post_d16_id AND tag_id = @ciclismo_id);

COMMIT;

-- IDs gerados variam por banco. Use esta consulta para localizar os posts dos cenários.
SELECT id, conteudo, usuario_id
FROM posts
WHERE conteudo LIKE '[HH-MASSA-D15]%' OR conteudo LIKE '[HH-MASSA-D16]%'
ORDER BY conteudo;
