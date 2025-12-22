-- IoT Smart Lock System - Database Schema
-- Supabase PostgreSQL

-- ============================================
-- 1. IoT Devices Table (Smart Locks)
-- ============================================
CREATE TABLE IF NOT EXISTS iot_devices (
    id BIGSERIAL PRIMARY KEY,
    device_id VARCHAR(100) UNIQUE NOT NULL,  -- Unique device identifier (e.g., MAC address)
    device_name VARCHAR(255) NOT NULL,
    device_type VARCHAR(50) NOT NULL DEFAULT 'smart_lock',  -- smart_lock, sensor, etc.
    asset_id UUID REFERENCES assets(id) ON DELETE SET NULL,  -- Linked to rental asset
    
    -- Device Status
    is_online BOOLEAN DEFAULT FALSE,
    lock_state VARCHAR(20) DEFAULT 'locked',  -- locked, unlocked, jammed, unknown
    battery_level INTEGER DEFAULT 100,  -- 0-100%
    signal_strength INTEGER DEFAULT 0,  -- WiFi signal strength
    firmware_version VARCHAR(50),
    
    -- Network Info
    ip_address INET,
    mac_address MACADDR,
    last_seen_at TIMESTAMP WITH TIME ZONE,
    
    -- Metadata
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Security
    api_key VARCHAR(255) UNIQUE NOT NULL,  -- Device authentication key
    
    CONSTRAINT valid_lock_state CHECK (lock_state IN ('locked', 'unlocked', 'jammed', 'unknown'))
);

-- Index for fast lookups
CREATE INDEX idx_iot_devices_device_id ON iot_devices(device_id);
CREATE INDEX idx_iot_devices_asset_id ON iot_devices(asset_id);
CREATE INDEX idx_iot_devices_is_online ON iot_devices(is_online);
CREATE INDEX idx_iot_devices_api_key ON iot_devices(api_key);

-- ============================================
-- 2. Device Commands Table (Command Queue)
-- ============================================
CREATE TABLE IF NOT EXISTS device_commands (
    id BIGSERIAL PRIMARY KEY,
    device_id BIGINT REFERENCES iot_devices(id) ON DELETE CASCADE,
    command_type VARCHAR(50) NOT NULL,  -- unlock, lock, status, reboot, update_firmware
    command_payload JSONB DEFAULT '{}'::jsonb,  -- Additional command parameters
    
    -- Command Status
    status VARCHAR(20) DEFAULT 'pending',  -- pending, sent, acknowledged, completed, failed
    priority INTEGER DEFAULT 1,  -- 1=low, 5=high
    
    -- Execution Info
    issued_by_user_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
    issued_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    executed_at TIMESTAMP WITH TIME ZONE,
    completed_at TIMESTAMP WITH TIME ZONE,
    
    -- Response
    response_data JSONB DEFAULT '{}'::jsonb,
    error_message TEXT,
    retry_count INTEGER DEFAULT 0,
    max_retries INTEGER DEFAULT 3,
    
    -- Expiry
    expires_at TIMESTAMP WITH TIME ZONE DEFAULT (NOW() + INTERVAL '5 minutes'),
    
    CONSTRAINT valid_command_type CHECK (command_type IN ('unlock', 'lock', 'status', 'reboot', 'update_firmware')),
    CONSTRAINT valid_status CHECK (status IN ('pending', 'sent', 'acknowledged', 'completed', 'failed', 'expired'))
);

-- Indexes for command queue
CREATE INDEX idx_device_commands_device_id ON device_commands(device_id);
CREATE INDEX idx_device_commands_status ON device_commands(status);
CREATE INDEX idx_device_commands_created_at ON device_commands(issued_at DESC);
CREATE INDEX idx_device_commands_priority ON device_commands(priority DESC, issued_at ASC);

-- ============================================
-- 3. Device Logs Table (Activity History)
-- ============================================
CREATE TABLE IF NOT EXISTS device_logs (
    id BIGSERIAL PRIMARY KEY,
    device_id BIGINT REFERENCES iot_devices(id) ON DELETE CASCADE,
    log_level VARCHAR(20) NOT NULL,  -- info, warning, error, critical
    event_type VARCHAR(50) NOT NULL,  -- lock_opened, lock_closed, offline, online, battery_low, etc.
    message TEXT NOT NULL,
    metadata JSONB DEFAULT '{}'::jsonb,  -- Additional event data
    
    -- Context
    triggered_by_user_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
    triggered_by_command_id BIGINT REFERENCES device_commands(id) ON DELETE SET NULL,
    
    -- Timestamp
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    CONSTRAINT valid_log_level CHECK (log_level IN ('info', 'warning', 'error', 'critical'))
);

-- Indexes for logs (optimized for time-based queries)
CREATE INDEX idx_device_logs_device_id ON device_logs(device_id);
CREATE INDEX idx_device_logs_created_at ON device_logs(created_at DESC);
CREATE INDEX idx_device_logs_log_level ON device_logs(log_level);
CREATE INDEX idx_device_logs_event_type ON device_logs(event_type);

-- ============================================
-- 4. Triggers for Auto-Update
-- ============================================

-- Auto-update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_iot_devices_updated_at
    BEFORE UPDATE ON iot_devices
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- 5. Row Level Security (RLS)
-- ============================================

-- Enable RLS
ALTER TABLE iot_devices ENABLE ROW LEVEL SECURITY;
ALTER TABLE device_commands ENABLE ROW LEVEL SECURITY;
ALTER TABLE device_logs ENABLE ROW LEVEL SECURITY;

-- Policies (for now, allow all authenticated users - customize based on your needs)
CREATE POLICY "Allow authenticated users to view devices"
    ON iot_devices FOR SELECT
    TO authenticated
    USING (true);

CREATE POLICY "Allow authenticated users to insert devices"
    ON iot_devices FOR INSERT
    TO authenticated
    WITH CHECK (true);

CREATE POLICY "Allow authenticated users to update devices"
    ON iot_devices FOR UPDATE
    TO authenticated
    USING (true);

CREATE POLICY "Allow authenticated users to view commands"
    ON device_commands FOR SELECT
    TO authenticated
    USING (true);

CREATE POLICY "Allow authenticated users to create commands"
    ON device_commands FOR INSERT
    TO authenticated
    WITH CHECK (true);

CREATE POLICY "Allow authenticated users to view logs"
    ON device_logs FOR SELECT
    TO authenticated
    USING (true);

-- ============================================
-- 6. Helper Functions
-- ============================================

-- Function to mark expired commands
CREATE OR REPLACE FUNCTION mark_expired_commands()
RETURNS INTEGER AS $$
DECLARE
    expired_count INTEGER;
BEGIN
    UPDATE device_commands
    SET status = 'expired'
    WHERE status IN ('pending', 'sent')
      AND expires_at < NOW();
    
    GET DIAGNOSTICS expired_count = ROW_COUNT;
    RETURN expired_count;
END;
$$ LANGUAGE plpgsql;

-- Function to get device statistics
CREATE OR REPLACE FUNCTION get_device_stats(p_device_id BIGINT)
RETURNS TABLE (
    total_commands INTEGER,
    completed_commands INTEGER,
    failed_commands INTEGER,
    avg_response_time INTERVAL,
    uptime_percentage NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*)::INTEGER as total_commands,
        COUNT(CASE WHEN status = 'completed' THEN 1 END)::INTEGER as completed_commands,
        COUNT(CASE WHEN status = 'failed' THEN 1 END)::INTEGER as failed_commands,
        AVG(completed_at - issued_at) as avg_response_time,
        CASE 
            WHEN COUNT(*) > 0 THEN 
                (COUNT(CASE WHEN status = 'completed' THEN 1 END)::NUMERIC / COUNT(*)::NUMERIC * 100)
            ELSE 0
        END as uptime_percentage
    FROM device_commands
    WHERE device_id = p_device_id;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- COMMENTS
-- ============================================

COMMENT ON TABLE iot_devices IS 'Stores IoT device information (smart locks, sensors, etc.)';
COMMENT ON TABLE device_commands IS 'Command queue for IoT devices';
COMMENT ON TABLE device_logs IS 'Activity and event logs for IoT devices';
COMMENT ON COLUMN iot_devices.api_key IS 'Unique API key for device authentication';
COMMENT ON COLUMN device_commands.priority IS 'Command priority: 1=low, 5=high';
COMMENT ON COLUMN device_commands.expires_at IS 'Command expires if not executed by this time';

