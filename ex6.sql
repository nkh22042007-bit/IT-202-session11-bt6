USE RikkeiClinicDB;

-- =============================================================
-- 1. STORED PROCEDURE: ProcessPrescription
-- Nhiệm vụ: Tự động hóa kiểm tra kho, tính tiền, giảm giá và cộng nợ
-- =============================================================
DROP PROCEDURE IF EXISTS ProcessPrescription;

DELIMITER //

CREATE PROCEDURE ProcessPrescription(
    IN p_patient_id INT,
    IN p_medicine_id INT,
    IN p_quantity INT,
    IN p_discount_code VARCHAR(20),
    OUT p_message VARCHAR(255)
)
BEGIN
    DECLARE v_stock INT;
    DECLARE v_price DECIMAL(18,2);
    DECLARE v_total_amount DECIMAL(18,2);

    -- Bước 1: Lấy thông tin thuốc (Giá và Tồn kho)
    SELECT stock, price INTO v_stock, v_price 
    FROM Medicines 
    WHERE medicine_id = p_medicine_id;

    -- Bước 2: Kiểm tra ràng buộc Out of Stock (Ràng buộc mục 3 trong ảnh)
    IF v_stock IS NULL THEN
        SET p_message = 'Thất bại: Thuốc không tồn tại';
    ELSEIF v_stock < p_quantity THEN
        SET p_message = 'Thất bại: Kho không đủ thuốc';
    ELSE
        -- Bước 3: Tính thành tiền = Số lượng * Đơn giá
        SET v_total_amount = v_price * p_quantity;

        -- Bước 4: Áp dụng chính sách trợ giá (Ràng buộc mục 2 trong ảnh)
        -- Mã 'NV-RIKKEI' giảm 50%, các mã khác hoặc NULL tính giá gốc
        IF p_discount_code = 'NV-RIKKEI' THEN
            SET v_total_amount = v_total_amount * 0.5;
        END IF;

        -- Bước 5: Cập nhật Database (Thực hiện giao dịch)
        -- 5.1. Trừ số lượng thuốc trong kho
        UPDATE Medicines 
        SET stock = stock - p_quantity 
        WHERE medicine_id = p_medicine_id;

        -- 5.2. Cộng dồn vào "Tổng nợ" (total_due) của bệnh nhân
        UPDATE Patient_Invoices 
        SET total_due = total_due + v_total_amount,
            last_updated = CURRENT_TIMESTAMP
        WHERE patient_id = p_patient_id;

        -- Bước 6: Trả về thông báo thành công
        SET p_message = 'Thành công: Đã xử lý đơn thuốc';
    END IF;
END //

DELIMITER ;


-- =============================================================
-- 2. KỊCH BẢN KIỂM THỬ (TEST CASES) - Theo mục 4 trong ảnh
-- =============================================================

-- Kịch bản 1: Kê đơn bình thường, không có mã giảm giá
-- Bệnh nhân 1 mua 2 Amoxicillin (15.000 * 2 = 30.000)
CALL ProcessPrescription(1, 1, 2, NULL, @msg1);
SELECT @msg1 AS 'Status_Case_1', total_due FROM Patient_Invoices WHERE patient_id = 1;


-- Kịch bản 2: Kê đơn có mã giảm giá 'NV-RIKKEI'
-- Bệnh nhân 2 mua 1 Amoxicillin (15.000 * 1 * 50% = 7.500)
CALL ProcessPrescription(2, 1, 1, 'NV-RIKKEI', @msg2);
SELECT @msg2 AS 'Status_Case_2', total_due FROM Patient_Invoices WHERE patient_id = 2;


-- Kịch bản 3: Kê đơn vượt quá số lượng tồn kho (Lỗi Out of Stock)
-- Thuốc Panadol (ID=2) chỉ còn 5 sản phẩm, yêu cầu mua 10
CALL ProcessPrescription(3, 2, 10, NULL, @msg3);
SELECT @msg3 AS 'Status_Case_3';

-- Xem lại bảng Thuốc sau khi đã trừ kho
SELECT * FROM Medicines;