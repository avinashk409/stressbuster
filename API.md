# StressBuster API Documentation

## Authentication

### User Authentication

#### Sign Up
```http
POST /api/auth/signup
Content-Type: application/json

{
  "email": "user@example.com",
  "password": "password123",
  "name": "John Doe",
  "phone": "+1234567890"
}
```

#### Sign In
```http
POST /api/auth/signin
Content-Type: application/json

{
  "email": "user@example.com",
  "password": "password123"
}
```

#### Phone Authentication
```http
POST /api/auth/phone
Content-Type: application/json

{
  "phone": "+1234567890"
}
```

## User Management

### Profile

#### Get Profile
```http
GET /api/users/profile
Authorization: Bearer <token>
```

#### Update Profile
```http
PUT /api/users/profile
Authorization: Bearer <token>
Content-Type: application/json

{
  "name": "John Doe",
  "age": 25,
  "gender": "male"
}
```

## Counseling

### Appointments

#### Create Appointment
```http
POST /api/appointments
Authorization: Bearer <token>
Content-Type: application/json

{
  "counselorId": "counselor123",
  "date": "2024-03-20",
  "time": "14:00",
  "duration": 60,
  "type": "video"
}
```

#### Get Appointments
```http
GET /api/appointments
Authorization: Bearer <token>
```

### Chat

#### Send Message
```http
POST /api/chats/{chatId}/messages
Authorization: Bearer <token>
Content-Type: application/json

{
  "content": "Hello, I need help with anxiety",
  "type": "text"
}
```

#### Get Messages
```http
GET /api/chats/{chatId}/messages
Authorization: Bearer <token>
```

## Payments

### Wallet

#### Add Money
```http
POST /api/wallet/add
Authorization: Bearer <token>
Content-Type: application/json

{
  "amount": 1000,
  "paymentMethod": "upi"
}
```

#### Get Balance
```http
GET /api/wallet/balance
Authorization: Bearer <token>
```

#### Get Transactions
```http
GET /api/wallet/transactions
Authorization: Bearer <token>
```

## Error Responses

All API endpoints may return the following error responses:

```json
{
  "error": {
    "code": "ERROR_CODE",
    "message": "Error description"
  }
}
```

Common error codes:
- `AUTH_REQUIRED`: Authentication required
- `INVALID_CREDENTIALS`: Invalid email/password
- `INVALID_TOKEN`: Invalid or expired token
- `RESOURCE_NOT_FOUND`: Requested resource not found
- `VALIDATION_ERROR`: Invalid request data
- `SERVER_ERROR`: Internal server error

## Rate Limiting

- Authentication endpoints: 5 requests per minute
- Other endpoints: 60 requests per minute

## WebSocket Events

### Chat Events

```javascript
// New message
{
  "type": "message",
  "data": {
    "chatId": "chat123",
    "message": {
      "id": "msg123",
      "content": "Hello",
      "senderId": "user123",
      "timestamp": "2024-03-20T14:00:00Z"
    }
  }
}

// Typing indicator
{
  "type": "typing",
  "data": {
    "chatId": "chat123",
    "userId": "user123",
    "isTyping": true
  }
}
```

### Appointment Events

```javascript
// Appointment status update
{
  "type": "appointment_update",
  "data": {
    "appointmentId": "apt123",
    "status": "confirmed",
    "timestamp": "2024-03-20T14:00:00Z"
  }
}
```

## Security

- All API endpoints require HTTPS
- Authentication tokens expire after 24 hours
- Rate limiting is applied to prevent abuse
- Input validation is performed on all requests
- Sensitive data is encrypted in transit and at rest 