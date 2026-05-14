CREATE DATABASE ex6;
use ex6;


CREATE TABLE Medicines (
    medicine_id INT PRIMARY KEY,
    name VARCHAR(100),
    price DECIMAL(15, 2),
    stock INT
);

CREATE TABLE Patient_Invoices (
    patient_id INT PRIMARY KEY,
    total_due DECIMAL(15, 2) DEFAULT 0
);

-- Dữ liệu mẫu
INSERT INTO Medicines VALUES (1, 'Paracetamol', 10000, 50);
INSERT INTO Patient_Invoices (patient_id, total_due) VALUES (101, 0);

DELIMITER //

CREATE PROCEDURE ProcessPrescription(
    IN p_patient_id INT,
    IN p_medicine_id INT,
    IN p_quantity INT,
    IN p_discount_code VARCHAR(20),
    OUT p_status_msg VARCHAR(255)
)
BEGIN
    DECLARE v_stock INT;
    DECLARE v_unit_price DECIMAL(15, 2);
    DECLARE v_final_price DECIMAL(15, 2);

    -- Lấy thông tin thuốc
    SELECT stock, price INTO v_stock, v_unit_price 
    FROM Medicines WHERE medicine_id = p_medicine_id;

    -- 1. Bẫy Out of stock
    IF v_stock < p_quantity THEN
        SET p_status_msg = 'Thất bại: Kho không đủ thuốc';
    ELSE
        -- 2. Tính toán tiền và áp dụng mã giảm giá
        IF p_discount_code = 'NV-RIKKEI' THEN
            SET v_final_price = (p_quantity * v_unit_price) * 0.5;
        ELSE
            SET v_final_price = (p_quantity * v_unit_price);
        END IF;

        -- 3. Thực hiện cập nhật dữ liệu
        START TRANSACTION;
            -- Trừ kho
            UPDATE Medicines 
            SET stock = stock - p_quantity 
            WHERE medicine_id = p_medicine_id;

            -- Cộng dồn nợ cho bệnh nhân
            UPDATE Patient_Invoices 
            SET total_due = total_due + v_final_price 
            WHERE patient_id = p_patient_id;
        COMMIT;

        SET p_status_msg = 'Thành công: Đã xử lý đơn thuốc';
    END IF;
END //

DELIMITER ;

SET @msg = '';

-- (1) Kê đơn bình thường, không mã giảm giá
CALL ProcessPrescription(101, 1, 2, NULL, @msg);
SELECT @msg; -- Mong đợi: Thành công, cộng 20.000 vào nợ.

-- (2) Kê đơn có mã giảm giá NV-RIKKEI
CALL ProcessPrescription(101, 1, 2, 'NV-RIKKEI', @msg);
SELECT @msg; -- Mong đợi: Thành công, cộng 10.000 vào nợ.

-- (3) Kê đơn vượt quá số lượng tồn kho (Bẫy lỗi)
CALL ProcessPrescription(101, 1, 100, NULL, @msg);
SELECT @msg; -- Mong đợi: Thất bại: Kho không đủ thuốc.