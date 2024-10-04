-- ATTENZIONE: cambiare il percorso del file (prodotti.csv e clienti.txt) nella riga 212 e riga 218

############################################################################
################           Creazione database              #################
############################################################################

drop database if exists Sneakerheads;
create database if not exists Sneakerheads;
use Sneakerheads;

############################################################################
################            Creazione tabelle              #################
############################################################################

drop table if exists Inserimento;
drop table if exists Effettuazione;
drop table if exists Fattura;
drop table if exists Ordine;
drop table if exists Carrello;
drop table if exists Giacenza;
drop table if exists Prodotto;
drop table if exists Cliente;

create table if not exists Cliente(
username varchar(20) primary key,
nome varchar(20),
email varchar(50),
indirizzo varchar(50),
partitaIva varchar(11) default NULL,
telefono varchar(10)
) ENGINE=INNODB;

create table if not exists Prodotto(
idProdotto varchar(7) primary key,
nome varchar(50),
categoria varchar(20),
produttore varchar(20),
anno year default NULL,
prezzo decimal(6,2)
) ENGINE=INNODB;

create table if not exists Giacenza(
barcode int not null AUTO_INCREMENT,
idProdotto varchar(7),
primary key(barcode),
foreign key (idProdotto) references Prodotto(idProdotto) on delete no action
);

create table if not exists Carrello(
idCarrello int not null AUTO_INCREMENT,
quantita int default 0,
primary key(idCarrello)
) ENGINE=INNODB;

create table if not exists Ordine(
numOrdine int not null AUTO_INCREMENT,
dataOrdine date,
speseSpedizione int,
stato varchar(20),
idCarrello int not null,
primary key(numOrdine),
foreign key (idCarrello) references Carrello(idCarrello) on delete no action
) ENGINE=INNODB;

create table if not exists Fattura(
idFattura int not null AUTO_INCREMENT,
sconto decimal(6,2) default 0.00,
dataFattura date,
numOrdine int,
primary key(idFattura),
foreign key (numOrdine) references Ordine(numOrdine)
) ENGINE=INNODB;

create table if not exists Effettuazione(
numOrdine int not null,
username varchar(20) not null,
primary key(numOrdine, username),
foreign key (numOrdine) references Ordine(numOrdine) on delete no action,
foreign key (username) references Cliente(username) on delete no action
) ENGINE=INNODB;

create table if not exists Inserimento(
barcode int not null,
idCarrello int not null,
primary key(barcode, idCarrello),
foreign key (barcode) references Giacenza(barcode) on delete no action,
foreign key (idCarrello) references Carrello(idCarrello) on delete no action
) ENGINE=INNODB;

############################################################################
################        Operazioni a livello di schema     #################
############################################################################

ALTER TABLE Carrello
ADD costoTotale decimal(6,2) default 0.00;

ALTER TABLE Cliente
MODIFY nome VARCHAR(50);

############################################################################
################                   Vista                   #################
############################################################################

DROP VIEW IF EXISTS view_ordini_in_corso;

create view view_ordini_in_corso as 
select ordine.numOrdine as numero_ordine,
		ordine.dataOrdine as data_ordine,
        carrello.quantita as quantita_ordinata,
        carrello.costoTotale as costo_totale,
        ordine.speseSpedizione as spese_spedizione,
        cliente.username as username_cliente,
        cliente.indirizzo as indirizzo_cliente
from ordine
inner join carrello
	on ordine.idCarrello = carrello.idCarrello
inner join effettuazione
	on ordine.numOrdine = effettuazione.numOrdine
inner join cliente
	on effettuazione.username = cliente.username
where ordine.stato = 'in corso'
with local check option;

############################################################################
################                  Funzione                 #################
############################################################################

DROP FUNCTION IF EXISTS function_fatturato_per_prodotto;

DELIMITER $$
CREATE FUNCTION function_fatturato_per_cliente(utente VARCHAR(20))
RETURNS INT
BEGIN
 DECLARE num INT DEFAULT 0;
	SELECT count(*) INTO num
	FROM fattura
	INNER JOIN ordine
		ON fattura.numOrdine = ordine.numOrdine
	INNER JOIN effettuazione
		ON ordine.numOrdine = effettuazione.numOrdine
	INNER JOIN cliente
		ON effettuazione.username = cliente.username
	WHERE cliente.username = utente;
 RETURN num;
END $$
DELIMITER ;

############################################################################
################                  Procedura                #################
############################################################################

DROP PROCEDURE IF EXISTS procedure_calcola_costototale;

DELIMITER $$
CREATE PROCEDURE procedure_calcola_costototale(idCart INT, numOrder INT)
BEGIN
 DECLARE n decimal(6,2) default 0.00;
 IF (idCart IN (SELECT idCarrello FROM Carrello WHERE Carrello.idCarrello=idCart))
 THEN
	SELECT SUM(Prodotto.prezzo) INTO n
	FROM Carrello
	INNER JOIN Inserimento
		ON Carrello.idCarrello = Inserimento.idCarrello
	INNER JOIN Giacenza
		ON Inserimento.barcode = Giacenza.barcode
	INNER JOIN Prodotto
		ON Giacenza.idProdotto = Prodotto.idProdotto
	WHERE Carrello.idCarrello = idCart;
 END IF;
 
 IF(n > 0.00)
 THEN
	 UPDATE Carrello SET costoTotale=n WHERE idCarrello = idCart;
 END IF;
END $$
DELIMITER ;

############################################################################
################                    Trigger                #################
############################################################################

DROP TRIGGER IF EXISTS trigger_calcola_quantita;
DELIMITER $$
CREATE TRIGGER trigger_calcola_quantita
AFTER INSERT ON Inserimento
FOR EACH ROW
BEGIN
	DECLARE n INT;
    SELECT COUNT(*) INTO n FROM Inserimento WHERE Inserimento.idCarrello=NEW.idCarrello;
	IF (n > 0)
		THEN UPDATE Carrello SET quantita=n WHERE idCarrello=NEW.idCarrello;
	END IF;
END $$
DELIMITER ;

DROP TRIGGER IF EXISTS trigger_calcola_prezzo;
DELIMITER $$
CREATE TRIGGER trigger_calcola_prezzo
AFTER INSERT ON Ordine
FOR EACH ROW
BEGIN
	CALL procedure_calcola_costototale(NEW.idCarrello, NEW.numOrdine);
END $$
DELIMITER ;

############################################################################
################            Popolamento database           #################
############################################################################

SET GLOBAL local_infile=1;

load data local infile 'prodotti.csv'   -- ATTENZIONE: cambiare il percorso del file
into table Prodotto
fields terminated by ','
lines terminated by '\n'
ignore 1 rows;

load data local infile 'clienti.txt'    -- ATTENZIONE: cambiare il percorso del file
into table Cliente
fields terminated by ';'
optionally enclosed by'"'
lines terminated by '\n'
ignore 1 rows;

INSERT INTO Giacenza (barcode, idProdotto) VALUES 
(1523000, 3835006),
(1523001, 3835006),
(1523002, 3835006),
(1523003, 3835006),
(1523004, 3835006),
(1523005, 3835006),
(1523006, 4167004),
(1523007, 4167004),
(1523008, 4167004),
(1523009, 4167004),
(1523010, 4167004),
(1523011, 6991016),
(1523012, 6991016),
(1523013, 6991016),
(1523014, 6991016),
(1523015, 7294103),
(1523016, 7294103),
(1523017, 7294103),
(1523018, 7294103),
(1523019, 5804563),
(1523020, 5804563),
(1523021, 5804563),
(1523022, 5804563),
(1523023, 5804563),
(1523024, 5804563),
(1523025, 1193403),
(1523026, 1193403),
(1523027, 1193403),
(1523028, 1193403),
(1523029, 1193403),
(1523030, 1193403),
(1523031, 2408739),
(1523032, 2408739),
(1523033, 2408739),
(1523034, 2408739),
(1523035, 2408739),
(1523036, 2254368),
(1523037, 2254368),
(1523038, 2254368),
(1523039, 2254368),
(1523040, 2254368),
(1523041, 2254368),
(1523042, 2254368),
(1523043, 2254368),
(1523044, 8556188),
(1523045, 8556188),
(1523046, 8556188),
(1523047, 8556188),
(1523048, 8556188),
(1523049, 9586255),
(1523050, 9586255),
(1523051, 9586255),
(1523052, 9586255),
(1523053, 9586255),
(1523054, 5131584),
(1523055, 5131584),
(1523056, 5131584),
(1523057, 5131584),
(1523058, 5131584),
(1523059, 5131584),
(1523060, 5131584),
(1523061, 5131584),
(1523099, 5131584);

INSERT INTO Carrello (idCarrello, quantita) VALUES
(4167001,0),
(4167002,0),
(4167003,0),
(4167004,0),
(4167005,0),
(4167006,0),
(4167007,0);

INSERT INTO Inserimento (barcode, idCarrello) VALUES
(1523000,4167001),
(1523009,4167001),
(1523029,4167002),
(1523033,4167002),
(1523002,4167002),
(1523016,4167003),
(1523011,4167005),
(1523012,4167005),
(1523041,4167004),
(1523042,4167004),
(1523013,4167005),
(1523037,4167006),
(1523058,4167004);

INSERT INTO Ordine (numOrdine, dataOrdine, speseSpedizione, stato, idCarrello) VALUES 
(1,'2020-01-23',5,'concluso',4167001),
(2,'2020-03-16',18,'concluso',4167002),
(3,'2020-07-21',25,'concluso',4167003),
(4,'2020-12-11',5,'in corso',4167004),
(5,'2021-01-18',10,'concluso',4167005),
(6,'2021-01-24',8,'in corso',4167006);

INSERT INTO Fattura (idFattura, sconto, dataFattura, numOrdine) VALUES 
(1,'0.10','2020-01-23',1),
(2,'0.00','2020-03-26',2),
(3,'0.50','2020-07-24',3),
(4,'0.00','2021-01-18',5);

INSERT INTO Effettuazione (numOrdine, username) VALUES 
(1,'gamber'),
(2,'marco'),
(3,'simone'),
(4,'Cleo'),
(5,'Estevao'),
(6,'Lucas');

############################################################################
################                    Query                  #################
############################################################################

-- 1. trovare i clienti il cui hanno inserito partitaIva e termina con '8'
select * from cliente where partitaIva is not null and partitaIva like '%8';

-- 2. trovare i borcode di tutti i prodotti disponibili nel magazzino di tutti i modelli di 'Air Jordan' 
select idProdotto from Prodotto where nome like 'Air Jordan %';  

-- 3. trovare partitaIva dei clienti che tra '2020-01-01' e '2021-01-01' hanno effettuato un ordine
-- ed hanno la partitaIva presente in dati anagrafici corrispondenti.
select partitaIva from cliente where partitaIva is not null and username in 
(select username from effettuazione where numOrdine in
(select numOrdine from ordine where dataOrdine>='2020-01-01' and dataOrdine<='2021-01-01'));
 
-- Verifica Trigger & Procedures
INSERT INTO Inserimento VALUES ('1523050','4167007');
INSERT INTO Inserimento VALUES ('1523061','4167007');
SELECT * FROM Inserimento;
SELECT * FROM Carrello;

INSERT INTO Ordine (dataOrdine, speseSpedizione, stato, idCarrello)  VALUES ('2021-02-01',5,'in corso',4167007);
SELECT * FROM Carrello;

