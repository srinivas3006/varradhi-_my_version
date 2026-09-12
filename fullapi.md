{
  "openapi": "3.1.0",
  "info": {
    "title": "HM Backend API",
    "version": "1.0.0",
    "description": "Production API documentation generated from the Express route inventory."
  },
  "servers": [
    {
      "url": "https://harglimpublish-backend.onrender.com",
      "description": "Current deployment"
    },
    {
      "url": "http://localhost:5000",
      "description": "Local development"
    }
  ],
  "tags": [
    {
      "name": "System"
    },
    {
      "name": "Content"
    },
    {
      "name": "Authentication"
    },
    {
      "name": "Books"
    },
    {
      "name": "Categories"
    },
    {
      "name": "Orders"
    },
    {
      "name": "Uploads"
    },
    {
      "name": "Users"
    },
    {
      "name": "Authors"
    },
    {
      "name": "Author Access"
    },
    {
      "name": "Author Dashboard"
    },
    {
      "name": "Author Publishing"
    },
    {
      "name": "Publishing"
    },
    {
      "name": "Admin Core"
    },
    {
      "name": "Admin Content"
    },
    {
      "name": "Admin Users"
    },
    {
      "name": "Admin Categories"
    },
    {
      "name": "Admin Author Access"
    },
    {
      "name": "Admin Operations"
    },
    {
      "name": "Admin Invoices"
    },
    {
      "name": "Admin Notifications"
    },
    {
      "name": "Admin Shipments"
    },
    {
      "name": "Admin Analytics"
    },
    {
      "name": "Royalty Settlements"
    }
  ],
  "paths": {
    "/health": {
      "get": {
        "tags": [
          "System"
        ],
        "summary": "Health check",
        "description": "Health check. Controller: server.js. Authentication: Public. API routes are rate limited and return standard error envelopes. Returns server liveness only.",
        "operationId": "get_health",
        "security": [],
        "parameters": [],
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/content": {
      "get": {
        "tags": [
          "Content"
        ],
        "summary": "Get global CMS content",
        "description": "Get global CMS content. Controller: contentController.getContent. Authentication: Public. API routes are rate limited and return standard error envelopes.",
        "operationId": "get_api_content",
        "security": [],
        "parameters": [],
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/auth/register": {
      "post": {
        "tags": [
          "Authentication"
        ],
        "summary": "Register user",
        "description": "Register user. Controller: authController.registerUser. Authentication: Public. API routes are rate limited and return standard error envelopes. Auth endpoints use a stricter 10 requests per 15 minutes limiter.",
        "operationId": "post_api_auth_register",
        "security": [],
        "parameters": [],
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {
                "$ref": "#/components/schemas/RegisterRequest"
              },
              "examples": {
                "default": {
                  "summary": "RegisterRequest example",
                  "value": {
                    "name": "Ghani Reader",
                    "email": "user@example.com",
                    "password": "StrongPass123!"
                  }
                }
              }
            }
          }
        },
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
                      "data": {
                        "_id": "66b4f5a2a44d2c0012a9c100",
                        "name": "Ghani Reader",
                        "email": "user@example.com",
                        "role": "reader"
                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
                      "data": {
                        "_id": "66b4f5a2a44d2c0012a9c100",
                        "name": "Ghani Reader",
                        "email": "user@example.com",
                        "role": "reader"
                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/auth/login": {
      "post": {
        "tags": [
          "Authentication"
        ],
        "summary": "Login user",
        "description": "Login user. Controller: authController.loginUser. Authentication: Public. API routes are rate limited and return standard error envelopes. Auth endpoints use a stricter 10 requests per 15 minutes limiter and return a JWT token on success.",
        "operationId": "post_api_auth_login",
        "security": [],
        "parameters": [],
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {
                "$ref": "#/components/schemas/LoginRequest"
              },
              "examples": {
                "default": {
                  "summary": "LoginRequest example",
                  "value": {
                    "email": "user@example.com",
                    "password": "StrongPass123!"
                  }
                }
              }
            }
          }
        },
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
                      "data": {
                        "_id": "66b4f5a2a44d2c0012a9c100",
                        "name": "Ghani Reader",
                        "email": "user@example.com",
                        "role": "reader"
                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
                      "data": {
                        "_id": "66b4f5a2a44d2c0012a9c100",
                        "name": "Ghani Reader",
                        "email": "user@example.com",
                        "role": "reader"
                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/auth/google": {
      "post": {
        "tags": [
          "Authentication"
        ],
        "summary": "Login or sign up with Google Identity Services credential",
        "description": "Login or sign up with Google Identity Services credential. Controller: authController.googleLogin. Authentication: Public. API routes are rate limited and return standard error envelopes. Server verifies Google ID token against GOOGLE_CLIENT_ID. New Google users are always created as reader.",
        "operationId": "post_api_auth_google",
        "security": [],
        "parameters": [],
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {
                "$ref": "#/components/schemas/GoogleLoginRequest"
              },
              "examples": {
                "default": {
                  "summary": "GoogleLoginRequest example",
                  "value": {
                    "credential": "\u003CGOOGLE_ID_TOKEN\u003E"
                  }
                }
              }
            }
          }
        },
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
                      "data": {
                        "_id": "66b4f5a2a44d2c0012a9c100",
                        "name": "Ghani Reader",
                        "email": "user@example.com",
                        "role": "reader"
                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
                      "data": {
                        "_id": "66b4f5a2a44d2c0012a9c100",
                        "name": "Ghani Reader",
                        "email": "user@example.com",
                        "role": "reader"
                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/auth/refresh": {
      "post": {
        "tags": [
          "Authentication"
        ],
        "summary": "Refresh access token using refresh token or bearer fallback",
        "description": "Refresh access token using refresh token or bearer fallback. Controller: authController.refreshToken. Authentication: Public/Bearer. API routes are rate limited and return standard error envelopes.",
        "operationId": "post_api_auth_refresh",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [],
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {
                "$ref": "#/components/schemas/RefreshTokenRequest"
              },
              "examples": {
                "default": {
                  "summary": "RefreshTokenRequest example",
                  "value": {
                    "type": "object",
                    "properties": {
                      "refreshToken": {
                        "type": "string",
                        "description": "Opaque refresh token issued by login/register/reset-password."
                      }
                    }
                  }
                }
              }
            }
          }
        },
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
                      "data": {
                        "_id": "66b4f5a2a44d2c0012a9c100",
                        "name": "Ghani Reader",
                        "email": "user@example.com",
                        "role": "reader"
                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
                      "data": {
                        "_id": "66b4f5a2a44d2c0012a9c100",
                        "name": "Ghani Reader",
                        "email": "user@example.com",
                        "role": "reader"
                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/auth/logout": {
      "post": {
        "tags": [
          "Authentication"
        ],
        "summary": "Logout and revoke refresh session",
        "description": "Logout and revoke refresh session. Controller: authController.logoutUser. Authentication: Public/Bearer. API routes are rate limited and return standard error envelopes.",
        "operationId": "post_api_auth_logout",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [],
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {
                "$ref": "#/components/schemas/LogoutRequest"
              },
              "examples": {
                "default": {
                  "summary": "LogoutRequest example",
                  "value": {
                    "type": "object",
                    "properties": {
                      "refreshToken": {
                        "type": "string",
                        "description": "Refresh token to revoke. Optional when bearer token is supplied."
                      },
                      "all": {
                        "type": "boolean",
                        "default": false,
                        "description": "Revoke all active sessions for the authenticated user."
                      }
                    }
                  }
                }
              }
            }
          }
        },
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
                      "data": {
                        "_id": "66b4f5a2a44d2c0012a9c100",
                        "name": "Ghani Reader",
                        "email": "user@example.com",
                        "role": "reader"
                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
                      "data": {
                        "_id": "66b4f5a2a44d2c0012a9c100",
                        "name": "Ghani Reader",
                        "email": "user@example.com",
                        "role": "reader"
                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/auth/forgot-password": {
      "post": {
        "tags": [
          "Authentication"
        ],
        "summary": "Request password reset token",
        "description": "Request password reset token. Controller: authController.forgotPassword. Authentication: Public. API routes are rate limited and return standard error envelopes.",
        "operationId": "post_api_auth_forgot_password",
        "security": [],
        "parameters": [],
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {
                "$ref": "#/components/schemas/ForgotPasswordRequest"
              },
              "examples": {
                "default": {
                  "summary": "ForgotPasswordRequest example",
                  "value": {
                    "type": "object",
                    "required": [
                      "email"
                    ],
                    "properties": {
                      "email": {
                        "type": "string",
                        "format": "email"
                      }
                    }
                  }
                }
              }
            }
          }
        },
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
                      "data": {
                        "_id": "66b4f5a2a44d2c0012a9c100",
                        "name": "Ghani Reader",
                        "email": "user@example.com",
                        "role": "reader"
                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
                      "data": {
                        "_id": "66b4f5a2a44d2c0012a9c100",
                        "name": "Ghani Reader",
                        "email": "user@example.com",
                        "role": "reader"
                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/auth/me": {
      "get": {
        "tags": [
          "Authentication"
        ],
        "summary": "Get current user",
        "description": "Get current user. Controller: authController.getMe. Authentication: Bearer. API routes are rate limited and return standard error envelopes.",
        "operationId": "get_api_auth_me",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [],
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
                      "data": {
                        "_id": "66b4f5a2a44d2c0012a9c100",
                        "name": "Ghani Reader",
                        "email": "user@example.com",
                        "role": "reader"
                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
                      "data": {
                        "_id": "66b4f5a2a44d2c0012a9c100",
                        "name": "Ghani Reader",
                        "email": "user@example.com",
                        "role": "reader"
                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/auth/reset-password/{token}": {
      "put": {
        "tags": [
          "Authentication"
        ],
        "summary": "Reset password with token",
        "description": "Reset password with token. Controller: authController.resetPassword. Authentication: Public. API routes are rate limited and return standard error envelopes.",
        "operationId": "put_api_auth_reset_password_token",
        "security": [],
        "parameters": [
          {
            "name": "token",
            "in": "path",
            "required": true,
            "schema": {
              "type": "string"
            }
          }
        ],
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {
                "$ref": "#/components/schemas/ResetPasswordRequest"
              },
              "examples": {
                "default": {
                  "summary": "ResetPasswordRequest example",
                  "value": {
                    "type": "object",
                    "required": [
                      "password"
                    ],
                    "properties": {
                      "password": {
                        "type": "string",
                        "minLength": 6
                      }
                    }
                  }
                }
              }
            }
          }
        },
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
                      "data": {
                        "_id": "66b4f5a2a44d2c0012a9c100",
                        "name": "Ghani Reader",
                        "email": "user@example.com",
                        "role": "reader"
                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
                      "data": {
                        "_id": "66b4f5a2a44d2c0012a9c100",
                        "name": "Ghani Reader",
                        "email": "user@example.com",
                        "role": "reader"
                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      },
      "post": {
        "tags": [
          "Authentication"
        ],
        "summary": "Reset password with token alias",
        "description": "Reset password with token alias. Controller: authController.resetPassword. Authentication: Public. API routes are rate limited and return standard error envelopes.",
        "operationId": "post_api_auth_reset_password_token",
        "security": [],
        "parameters": [
          {
            "name": "token",
            "in": "path",
            "required": true,
            "schema": {
              "type": "string"
            }
          }
        ],
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {
                "$ref": "#/components/schemas/ResetPasswordRequest"
              },
              "examples": {
                "default": {
                  "summary": "ResetPasswordRequest example",
                  "value": {
                    "type": "object",
                    "required": [
                      "password"
                    ],
                    "properties": {
                      "password": {
                        "type": "string",
                        "minLength": 6
                      }
                    }
                  }
                }
              }
            }
          }
        },
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
                      "data": {
                        "_id": "66b4f5a2a44d2c0012a9c100",
                        "name": "Ghani Reader",
                        "email": "user@example.com",
                        "role": "reader"
                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
                      "data": {
                        "_id": "66b4f5a2a44d2c0012a9c100",
                        "name": "Ghani Reader",
                        "email": "user@example.com",
                        "role": "reader"
                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/auth/change-password": {
      "put": {
        "tags": [
          "Authentication"
        ],
        "summary": "Change current user password",
        "description": "Change current user password. Controller: authController.changePassword. Authentication: Bearer. API routes are rate limited and return standard error envelopes.",
        "operationId": "put_api_auth_change_password",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [],
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {
                "$ref": "#/components/schemas/ChangePasswordRequest"
              },
              "examples": {
                "default": {
                  "summary": "ChangePasswordRequest example",
                  "value": {
                    "type": "object",
                    "required": [
                      "currentPassword",
                      "password"
                    ],
                    "properties": {
                      "currentPassword": {
                        "type": "string",
                        "minLength": 6
                      },
                      "password": {
                        "type": "string",
                        "minLength": 6
                      }
                    }
                  }
                }
              }
            }
          }
        },
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
                      "data": {
                        "_id": "66b4f5a2a44d2c0012a9c100",
                        "name": "Ghani Reader",
                        "email": "user@example.com",
                        "role": "reader"
                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
                      "data": {
                        "_id": "66b4f5a2a44d2c0012a9c100",
                        "name": "Ghani Reader",
                        "email": "user@example.com",
                        "role": "reader"
                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      },
      "post": {
        "tags": [
          "Authentication"
        ],
        "summary": "Change current user password alias",
        "description": "Change current user password alias. Controller: authController.changePassword. Authentication: Bearer. API routes are rate limited and return standard error envelopes.",
        "operationId": "post_api_auth_change_password",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [],
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {
                "$ref": "#/components/schemas/ChangePasswordRequest"
              },
              "examples": {
                "default": {
                  "summary": "ChangePasswordRequest example",
                  "value": {
                    "type": "object",
                    "required": [
                      "currentPassword",
                      "password"
                    ],
                    "properties": {
                      "currentPassword": {
                        "type": "string",
                        "minLength": 6
                      },
                      "password": {
                        "type": "string",
                        "minLength": 6
                      }
                    }
                  }
                }
              }
            }
          }
        },
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
                      "data": {
                        "_id": "66b4f5a2a44d2c0012a9c100",
                        "name": "Ghani Reader",
                        "email": "user@example.com",
                        "role": "reader"
                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
                      "data": {
                        "_id": "66b4f5a2a44d2c0012a9c100",
                        "name": "Ghani Reader",
                        "email": "user@example.com",
                        "role": "reader"
                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/books": {
      "get": {
        "tags": [
          "Books"
        ],
        "summary": "List books",
        "description": "List books. Controller: bookController.getBooks. Authentication: Public. API routes are rate limited and return standard error envelopes.",
        "operationId": "get_api_books",
        "security": [],
        "parameters": [
          {
            "name": "page",
            "in": "query",
            "required": false,
            "schema": {
              "type": "integer",
              "minimum": 1,
              "default": 1
            }
          },
          {
            "name": "limit",
            "in": "query",
            "required": false,
            "schema": {
              "type": "integer",
              "minimum": 1,
              "maximum": 100,
              "default": 10
            }
          },
          {
            "name": "category",
            "in": "query",
            "required": false,
            "schema": {
              "type": "string"
            }
          },
          {
            "name": "minPrice",
            "in": "query",
            "required": false,
            "schema": {
              "type": "number",
              "minimum": 0
            }
          },
          {
            "name": "maxPrice",
            "in": "query",
            "required": false,
            "schema": {
              "type": "number",
              "minimum": 0
            }
          },
          {
            "name": "sort",
            "in": "query",
            "required": false,
            "schema": {
              "type": "string"
            }
          },
          {
            "name": "featured",
            "in": "query",
            "required": false,
            "schema": {
              "type": "boolean"
            }
          },
          {
            "name": "bestseller",
            "in": "query",
            "required": false,
            "schema": {
              "type": "boolean"
            }
          },
          {
            "name": "newRelease",
            "in": "query",
            "required": false,
            "schema": {
              "type": "boolean"
            }
          }
        ],
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": [
                        {
                          "_id": "66b4f5a2a44d2c0012a9c101",
                          "title": "Enterprise Publishing Systems",
                          "slug": "enterprise-publishing-systems",
                          "price": 499,
                          "status": "published"
                        }
                      ],
                      "pagination": {
                        "total": 1,
                        "page": 1,
                        "pages": 1
                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": [
                        {
                          "_id": "66b4f5a2a44d2c0012a9c101",
                          "title": "Enterprise Publishing Systems",
                          "slug": "enterprise-publishing-systems",
                          "price": 499,
                          "status": "published"
                        }
                      ],
                      "pagination": {
                        "total": 1,
                        "page": 1,
                        "pages": 1
                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/books/{slug}": {
      "get": {
        "tags": [
          "Books"
        ],
        "summary": "Get book by slug",
        "description": "Get book by slug. Controller: bookController.getBookBySlug. Authentication: Public. API routes are rate limited and return standard error envelopes.",
        "operationId": "get_api_books_slug",
        "security": [],
        "parameters": [
          {
            "name": "slug",
            "in": "path",
            "required": true,
            "schema": {
              "type": "string"
            }
          }
        ],
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": [
                        {
                          "_id": "66b4f5a2a44d2c0012a9c101",
                          "title": "Enterprise Publishing Systems",
                          "slug": "enterprise-publishing-systems",
                          "price": 499,
                          "status": "published"
                        }
                      ],
                      "pagination": {
                        "total": 1,
                        "page": 1,
                        "pages": 1
                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": [
                        {
                          "_id": "66b4f5a2a44d2c0012a9c101",
                          "title": "Enterprise Publishing Systems",
                          "slug": "enterprise-publishing-systems",
                          "price": 499,
                          "status": "published"
                        }
                      ],
                      "pagination": {
                        "total": 1,
                        "page": 1,
                        "pages": 1
                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/books/{slug}/related": {
      "get": {
        "tags": [
          "Books"
        ],
        "summary": "Get related books",
        "description": "Get related books. Controller: bookController.getRelatedBooks. Authentication: Public. API routes are rate limited and return standard error envelopes.",
        "operationId": "get_api_books_slug_related",
        "security": [],
        "parameters": [
          {
            "name": "slug",
            "in": "path",
            "required": true,
            "schema": {
              "type": "string"
            }
          }
        ],
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": [
                        {
                          "_id": "66b4f5a2a44d2c0012a9c101",
                          "title": "Enterprise Publishing Systems",
                          "slug": "enterprise-publishing-systems",
                          "price": 499,
                          "status": "published"
                        }
                      ],
                      "pagination": {
                        "total": 1,
                        "page": 1,
                        "pages": 1
                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": [
                        {
                          "_id": "66b4f5a2a44d2c0012a9c101",
                          "title": "Enterprise Publishing Systems",
                          "slug": "enterprise-publishing-systems",
                          "price": 499,
                          "status": "published"
                        }
                      ],
                      "pagination": {
                        "total": 1,
                        "page": 1,
                        "pages": 1
                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/books/{slug}/reviews": {
      "post": {
        "tags": [
          "Books"
        ],
        "summary": "Create book review",
        "description": "Create book review. Controller: reviewController.createReview. Authentication: Bearer. API routes are rate limited and return standard error envelopes.",
        "operationId": "post_api_books_slug_reviews",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [
          {
            "name": "slug",
            "in": "path",
            "required": true,
            "schema": {
              "type": "string"
            }
          }
        ],
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {
                "$ref": "#/components/schemas/ReviewRequest"
              },
              "examples": {
                "default": {
                  "summary": "ReviewRequest example",
                  "value": {
                    "type": "object",
                    "properties": {
                      "book": {
                        "type": "string"
                      },
                      "rating": {
                        "type": "integer",
                        "minimum": 1,
                        "maximum": 5
                      },
                      "comment": {
                        "type": "string"
                      }
                    }
                  }
                }
              }
            }
          }
        },
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": [
                        {
                          "_id": "66b4f5a2a44d2c0012a9c101",
                          "title": "Enterprise Publishing Systems",
                          "slug": "enterprise-publishing-systems",
                          "price": 499,
                          "status": "published"
                        }
                      ],
                      "pagination": {
                        "total": 1,
                        "page": 1,
                        "pages": 1
                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": [
                        {
                          "_id": "66b4f5a2a44d2c0012a9c101",
                          "title": "Enterprise Publishing Systems",
                          "slug": "enterprise-publishing-systems",
                          "price": 499,
                          "status": "published"
                        }
                      ],
                      "pagination": {
                        "total": 1,
                        "page": 1,
                        "pages": 1
                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/books/{slug}/reviews/{reviewId}": {
      "put": {
        "tags": [
          "Books"
        ],
        "summary": "Update book review",
        "description": "Update book review. Controller: reviewController.updateReview. Authentication: Bearer. API routes are rate limited and return standard error envelopes.",
        "operationId": "put_api_books_slug_reviews_reviewId",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [
          {
            "name": "slug",
            "in": "path",
            "required": true,
            "schema": {
              "type": "string"
            }
          },
          {
            "name": "reviewId",
            "in": "path",
            "required": true,
            "schema": {
              "type": "string"
            }
          }
        ],
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {
                "$ref": "#/components/schemas/ReviewRequest"
              },
              "examples": {
                "default": {
                  "summary": "ReviewRequest example",
                  "value": {
                    "type": "object",
                    "properties": {
                      "book": {
                        "type": "string"
                      },
                      "rating": {
                        "type": "integer",
                        "minimum": 1,
                        "maximum": 5
                      },
                      "comment": {
                        "type": "string"
                      }
                    }
                  }
                }
              }
            }
          }
        },
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": [
                        {
                          "_id": "66b4f5a2a44d2c0012a9c101",
                          "title": "Enterprise Publishing Systems",
                          "slug": "enterprise-publishing-systems",
                          "price": 499,
                          "status": "published"
                        }
                      ],
                      "pagination": {
                        "total": 1,
                        "page": 1,
                        "pages": 1
                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": [
                        {
                          "_id": "66b4f5a2a44d2c0012a9c101",
                          "title": "Enterprise Publishing Systems",
                          "slug": "enterprise-publishing-systems",
                          "price": 499,
                          "status": "published"
                        }
                      ],
                      "pagination": {
                        "total": 1,
                        "page": 1,
                        "pages": 1
                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      },
      "delete": {
        "tags": [
          "Books"
        ],
        "summary": "Delete book review",
        "description": "Delete book review. Controller: reviewController.deleteReview. Authentication: Bearer. API routes are rate limited and return standard error envelopes.",
        "operationId": "delete_api_books_slug_reviews_reviewId",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [
          {
            "name": "slug",
            "in": "path",
            "required": true,
            "schema": {
              "type": "string"
            }
          },
          {
            "name": "reviewId",
            "in": "path",
            "required": true,
            "schema": {
              "type": "string"
            }
          }
        ],
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": [
                        {
                          "_id": "66b4f5a2a44d2c0012a9c101",
                          "title": "Enterprise Publishing Systems",
                          "slug": "enterprise-publishing-systems",
                          "price": 499,
                          "status": "published"
                        }
                      ],
                      "pagination": {
                        "total": 1,
                        "page": 1,
                        "pages": 1
                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": [
                        {
                          "_id": "66b4f5a2a44d2c0012a9c101",
                          "title": "Enterprise Publishing Systems",
                          "slug": "enterprise-publishing-systems",
                          "price": 499,
                          "status": "published"
                        }
                      ],
                      "pagination": {
                        "total": 1,
                        "page": 1,
                        "pages": 1
                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/search": {
      "get": {
        "tags": [
          "Books"
        ],
        "summary": "Search books",
        "description": "Search books. Controller: bookController.searchBooks. Authentication: Public. API routes are rate limited and return standard error envelopes.",
        "operationId": "get_api_search",
        "security": [],
        "parameters": [
          {
            "name": "q",
            "in": "query",
            "required": false,
            "schema": {
              "type": "string"
            }
          },
          {
            "name": "page",
            "in": "query",
            "required": false,
            "schema": {
              "type": "integer",
              "minimum": 1,
              "default": 1
            }
          },
          {
            "name": "limit",
            "in": "query",
            "required": false,
            "schema": {
              "type": "integer",
              "minimum": 1,
              "maximum": 100,
              "default": 10
            }
          }
        ],
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": [
                        {
                          "_id": "66b4f5a2a44d2c0012a9c101",
                          "title": "Enterprise Publishing Systems",
                          "slug": "enterprise-publishing-systems",
                          "price": 499,
                          "status": "published"
                        }
                      ],
                      "pagination": {
                        "total": 1,
                        "page": 1,
                        "pages": 1
                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": [
                        {
                          "_id": "66b4f5a2a44d2c0012a9c101",
                          "title": "Enterprise Publishing Systems",
                          "slug": "enterprise-publishing-systems",
                          "price": 499,
                          "status": "published"
                        }
                      ],
                      "pagination": {
                        "total": 1,
                        "page": 1,
                        "pages": 1
                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/categories": {
      "get": {
        "tags": [
          "Categories"
        ],
        "summary": "List categories",
        "description": "List categories. Controller: categoryController.listCategories. Authentication: Public. API routes are rate limited and return standard error envelopes. Public list returns active categories by default and includes system-managed book counts.",
        "operationId": "get_api_categories",
        "security": [],
        "parameters": [
          {
            "name": "page",
            "in": "query",
            "required": false,
            "schema": {
              "type": "integer",
              "minimum": 1,
              "default": 1
            }
          },
          {
            "name": "limit",
            "in": "query",
            "required": false,
            "schema": {
              "type": "integer",
              "minimum": 1,
              "maximum": 100,
              "default": 10
            }
          },
          {
            "name": "featured",
            "in": "query",
            "required": false,
            "schema": {
              "type": "boolean"
            }
          },
          {
            "name": "active",
            "in": "query",
            "required": false,
            "schema": {
              "type": "boolean"
            }
          },
          {
            "name": "search",
            "in": "query",
            "required": false,
            "schema": {
              "type": "string"
            }
          },
          {
            "name": "sort",
            "in": "query",
            "required": false,
            "schema": {
              "type": "string"
            }
          }
        ],
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": [
                        {
                          "_id": "66b4f5a2a44d2c0012a9c102",
                          "name": "Business Books",
                          "slug": "business-books",
                          "active": true,
                          "featured": true,
                          "bookCount": 12
                        }
                      ],
                      "pagination": {
                        "total": 1,
                        "page": 1,
                        "limit": 10,
                        "pages": 1
                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": [
                        {
                          "_id": "66b4f5a2a44d2c0012a9c102",
                          "name": "Business Books",
                          "slug": "business-books",
                          "active": true,
                          "featured": true,
                          "bookCount": 12
                        }
                      ],
                      "pagination": {
                        "total": 1,
                        "page": 1,
                        "limit": 10,
                        "pages": 1
                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/categories/{slug}": {
      "get": {
        "tags": [
          "Categories"
        ],
        "summary": "Get category by slug",
        "description": "Get category by slug. Controller: categoryController.getCategoryBySlug. Authentication: Public. API routes are rate limited and return standard error envelopes. Only active categories are returned publicly.",
        "operationId": "get_api_categories_slug",
        "security": [],
        "parameters": [
          {
            "name": "slug",
            "in": "path",
            "required": true,
            "schema": {
              "type": "string"
            }
          }
        ],
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": [
                        {
                          "_id": "66b4f5a2a44d2c0012a9c102",
                          "name": "Business Books",
                          "slug": "business-books",
                          "active": true,
                          "featured": true,
                          "bookCount": 12
                        }
                      ],
                      "pagination": {
                        "total": 1,
                        "page": 1,
                        "limit": 10,
                        "pages": 1
                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": [
                        {
                          "_id": "66b4f5a2a44d2c0012a9c102",
                          "name": "Business Books",
                          "slug": "business-books",
                          "active": true,
                          "featured": true,
                          "bookCount": 12
                        }
                      ],
                      "pagination": {
                        "total": 1,
                        "page": 1,
                        "limit": 10,
                        "pages": 1
                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/categories/{slug}/books": {
      "get": {
        "tags": [
          "Categories"
        ],
        "summary": "List books by category",
        "description": "List books by category. Controller: categoryController.getCategoryBooks. Authentication: Public. API routes are rate limited and return standard error envelopes. Returns published books for an active category.",
        "operationId": "get_api_categories_slug_books",
        "security": [],
        "parameters": [
          {
            "name": "slug",
            "in": "path",
            "required": true,
            "schema": {
              "type": "string"
            }
          },
          {
            "name": "page",
            "in": "query",
            "required": false,
            "schema": {
              "type": "integer",
              "minimum": 1,
              "default": 1
            }
          },
          {
            "name": "limit",
            "in": "query",
            "required": false,
            "schema": {
              "type": "integer",
              "minimum": 1,
              "maximum": 100,
              "default": 10
            }
          },
          {
            "name": "sort",
            "in": "query",
            "required": false,
            "schema": {
              "type": "string"
            }
          }
        ],
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": [
                        {
                          "_id": "66b4f5a2a44d2c0012a9c102",
                          "name": "Business Books",
                          "slug": "business-books",
                          "active": true,
                          "featured": true,
                          "bookCount": 12
                        }
                      ],
                      "pagination": {
                        "total": 1,
                        "page": 1,
                        "limit": 10,
                        "pages": 1
                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": [
                        {
                          "_id": "66b4f5a2a44d2c0012a9c102",
                          "name": "Business Books",
                          "slug": "business-books",
                          "active": true,
                          "featured": true,
                          "bookCount": 12
                        }
                      ],
                      "pagination": {
                        "total": 1,
                        "page": 1,
                        "limit": 10,
                        "pages": 1
                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/orders": {
      "post": {
        "tags": [
          "Orders"
        ],
        "summary": "Create order with payment, inventory, QR bridge",
        "description": "Create order with payment, inventory, QR bridge. Controller: orderController.createOrder. Authentication: Bearer. API routes are rate limited and return standard error envelopes. New book checkout reloads Book.mrp from the database, keeps existing shipping logic, and persists tax=0. Client price/tax/total fields are not trusted.",
        "operationId": "post_api_orders",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [],
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {
                "$ref": "#/components/schemas/OrderCreateRequest"
              },
              "examples": {
                "default": {
                  "summary": "OrderCreateRequest example",
                  "value": {
                    "items": [
                      {
                        "book": "66b4f5a2a44d2c0012a9c101",
                        "quantity": 2
                      }
                    ],
                    "shippingAddress": {
                      "fullName": "Ghani Khan",
                      "addressLine1": "12 MG Road",
                      "addressLine2": "Near Central Mall",
                      "city": "Bengaluru",
                      "postalCode": "560001",
                      "country": "India"
                    },
                    "paymentMethod": "UPI"
                  }
                }
              }
            }
          }
        },
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {
                        "_id": "66b4f5a2a44d2c0012a9c120",
                        "orderNumber": "HM-20260710-0001",
                        "totalPrice": 998,
                        "isPaid": false,
                        "paymentMethod": "UPI",
                        "payment": "66b4f5a2a44d2c0012a9c130",
                        "qrCodeDataUrl": "data:image/png;base64,..."
                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {
                        "_id": "66b4f5a2a44d2c0012a9c120",
                        "orderNumber": "HM-20260710-0001",
                        "totalPrice": 998,
                        "isPaid": false,
                        "paymentMethod": "UPI",
                        "payment": "66b4f5a2a44d2c0012a9c130",
                        "qrCodeDataUrl": "data:image/png;base64,..."
                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/orders/{id}/verify-payment": {
      "put": {
        "tags": [
          "Orders"
        ],
        "summary": "Verify order payment reference",
        "description": "Verify order payment reference. Controller: orderController.verifyPayment. Authentication: Bearer. API routes are rate limited and return standard error envelopes.",
        "operationId": "put_api_orders_id_verify_payment",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [
          {
            "name": "id",
            "in": "path",
            "required": true,
            "schema": {
              "type": "string"
            }
          }
        ],
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {
                "$ref": "#/components/schemas/PaymentVerificationRequest"
              },
              "examples": {
                "default": {
                  "summary": "PaymentVerificationRequest example",
                  "value": {
                    "utr": "UPI1234567890"
                  }
                }
              }
            }
          }
        },
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {
                        "_id": "66b4f5a2a44d2c0012a9c120",
                        "orderNumber": "HM-20260710-0001",
                        "totalPrice": 998,
                        "isPaid": false,
                        "paymentMethod": "UPI",
                        "payment": "66b4f5a2a44d2c0012a9c130",
                        "qrCodeDataUrl": "data:image/png;base64,..."
                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {
                        "_id": "66b4f5a2a44d2c0012a9c120",
                        "orderNumber": "HM-20260710-0001",
                        "totalPrice": 998,
                        "isPaid": false,
                        "paymentMethod": "UPI",
                        "payment": "66b4f5a2a44d2c0012a9c130",
                        "qrCodeDataUrl": "data:image/png;base64,..."
                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/orders/{id}": {
      "delete": {
        "tags": [
          "Orders"
        ],
        "summary": "Cancel order",
        "description": "Cancel order. Controller: orderController.cancelOrder. Authentication: Bearer. API routes are rate limited and return standard error envelopes.",
        "operationId": "delete_api_orders_id",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [
          {
            "name": "id",
            "in": "path",
            "required": true,
            "schema": {
              "type": "string"
            }
          }
        ],
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {
                        "_id": "66b4f5a2a44d2c0012a9c120",
                        "orderNumber": "HM-20260710-0001",
                        "totalPrice": 998,
                        "isPaid": false,
                        "paymentMethod": "UPI",
                        "payment": "66b4f5a2a44d2c0012a9c130",
                        "qrCodeDataUrl": "data:image/png;base64,..."
                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {
                        "_id": "66b4f5a2a44d2c0012a9c120",
                        "orderNumber": "HM-20260710-0001",
                        "totalPrice": 998,
                        "isPaid": false,
                        "paymentMethod": "UPI",
                        "payment": "66b4f5a2a44d2c0012a9c130",
                        "qrCodeDataUrl": "data:image/png;base64,..."
                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/orders/{id}/shipment": {
      "get": {
        "tags": [
          "Orders"
        ],
        "summary": "Get order shipment",
        "description": "Get order shipment. Controller: orderShipmentController.getOrderShipment. Authentication: Bearer. API routes are rate limited and return standard error envelopes.",
        "operationId": "get_api_orders_id_shipment",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [
          {
            "name": "id",
            "in": "path",
            "required": true,
            "schema": {
              "type": "string"
            }
          }
        ],
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {
                        "_id": "66b4f5a2a44d2c0012a9c120",
                        "orderNumber": "HM-20260710-0001",
                        "totalPrice": 998,
                        "isPaid": false,
                        "paymentMethod": "UPI",
                        "payment": "66b4f5a2a44d2c0012a9c130",
                        "qrCodeDataUrl": "data:image/png;base64,..."
                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {
                        "_id": "66b4f5a2a44d2c0012a9c120",
                        "orderNumber": "HM-20260710-0001",
                        "totalPrice": 998,
                        "isPaid": false,
                        "paymentMethod": "UPI",
                        "payment": "66b4f5a2a44d2c0012a9c130",
                        "qrCodeDataUrl": "data:image/png;base64,..."
                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/orders/{id}/tracking": {
      "get": {
        "tags": [
          "Orders"
        ],
        "summary": "Get order tracking",
        "description": "Get order tracking. Controller: orderShipmentController.getOrderTracking. Authentication: Bearer. API routes are rate limited and return standard error envelopes.",
        "operationId": "get_api_orders_id_tracking",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [
          {
            "name": "id",
            "in": "path",
            "required": true,
            "schema": {
              "type": "string"
            }
          }
        ],
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {
                        "_id": "66b4f5a2a44d2c0012a9c120",
                        "orderNumber": "HM-20260710-0001",
                        "totalPrice": 998,
                        "isPaid": false,
                        "paymentMethod": "UPI",
                        "payment": "66b4f5a2a44d2c0012a9c130",
                        "qrCodeDataUrl": "data:image/png;base64,..."
                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {
                        "_id": "66b4f5a2a44d2c0012a9c120",
                        "orderNumber": "HM-20260710-0001",
                        "totalPrice": 998,
                        "isPaid": false,
                        "paymentMethod": "UPI",
                        "payment": "66b4f5a2a44d2c0012a9c130",
                        "qrCodeDataUrl": "data:image/png;base64,..."
                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/orders/track/{orderNumber}": {
      "get": {
        "tags": [
          "Orders"
        ],
        "summary": "Track order by order number",
        "description": "Track order by order number. Controller: orderController.trackOrder. Authentication: Public. API routes are rate limited and return standard error envelopes.",
        "operationId": "get_api_orders_track_orderNumber",
        "security": [],
        "parameters": [
          {
            "name": "orderNumber",
            "in": "path",
            "required": true,
            "schema": {
              "type": "string"
            }
          }
        ],
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {
                        "_id": "66b4f5a2a44d2c0012a9c120",
                        "orderNumber": "HM-20260710-0001",
                        "totalPrice": 998,
                        "isPaid": false,
                        "paymentMethod": "UPI",
                        "payment": "66b4f5a2a44d2c0012a9c130",
                        "qrCodeDataUrl": "data:image/png;base64,..."
                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {
                        "_id": "66b4f5a2a44d2c0012a9c120",
                        "orderNumber": "HM-20260710-0001",
                        "totalPrice": 998,
                        "isPaid": false,
                        "paymentMethod": "UPI",
                        "payment": "66b4f5a2a44d2c0012a9c130",
                        "qrCodeDataUrl": "data:image/png;base64,..."
                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/uploads/image": {
      "post": {
        "tags": [
          "Uploads"
        ],
        "summary": "Upload image",
        "description": "Upload image. Controller: uploadController.uploadImage. Authentication: Bearer. API routes are rate limited and return standard error envelopes. Multipart field: image. Allowed: jpg, jpeg, png, webp, gif. Default max size: 25MB. Requires CLOUDINARY_CLOUD_NAME, CLOUDINARY_API_KEY, CLOUDINARY_API_SECRET.",
        "operationId": "post_api_uploads_image",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [],
        "requestBody": {
          "required": true,
          "content": {
            "multipart/form-data": {
              "schema": {
                "$ref": "#/components/schemas/MultipartImageRequest"
              }
            }
          }
        },
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {
                        "url": "https://res.cloudinary.com/demo/image/upload/sample.jpg",
                        "public_id": "hm_uploads/sample"
                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {
                        "url": "https://res.cloudinary.com/demo/image/upload/sample.jpg",
                        "public_id": "hm_uploads/sample"
                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "503": {
            "$ref": "#/components/responses/ServiceUnavailable"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/uploads/document": {
      "post": {
        "tags": [
          "Uploads"
        ],
        "summary": "Upload document",
        "description": "Upload document. Controller: uploadController.uploadDocument. Authentication: Bearer. API routes are rate limited and return standard error envelopes. Multipart field: document. Allowed: pdf, doc, docx. Default max size: 25MB. Requires CLOUDINARY_CLOUD_NAME, CLOUDINARY_API_KEY, CLOUDINARY_API_SECRET.",
        "operationId": "post_api_uploads_document",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [],
        "requestBody": {
          "required": true,
          "content": {
            "multipart/form-data": {
              "schema": {
                "$ref": "#/components/schemas/MultipartDocumentRequest"
              }
            }
          }
        },
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {
                        "url": "https://res.cloudinary.com/demo/image/upload/sample.jpg",
                        "public_id": "hm_uploads/sample"
                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {
                        "url": "https://res.cloudinary.com/demo/image/upload/sample.jpg",
                        "public_id": "hm_uploads/sample"
                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "503": {
            "$ref": "#/components/responses/ServiceUnavailable"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/users/me": {
      "get": {
        "tags": [
          "Users"
        ],
        "summary": "Get current user profile",
        "description": "Get current user profile. Controller: userController.getCurrentUser. Authentication: Bearer. API routes are rate limited and return standard error envelopes.",
        "operationId": "get_api_users_me",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [],
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/users/{id}/stats": {
      "get": {
        "tags": [
          "Users"
        ],
        "summary": "Get user stats",
        "description": "Get user stats. Controller: userController.getUserStats. Authentication: Bearer. API routes are rate limited and return standard error envelopes.",
        "operationId": "get_api_users_id_stats",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [
          {
            "name": "id",
            "in": "path",
            "required": true,
            "schema": {
              "type": "string"
            }
          }
        ],
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/users/{id}": {
      "put": {
        "tags": [
          "Users"
        ],
        "summary": "Update user profile",
        "description": "Update user profile. Controller: userController.updateUserProfile. Authentication: Bearer. API routes are rate limited and return standard error envelopes.",
        "operationId": "put_api_users_id",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [
          {
            "name": "id",
            "in": "path",
            "required": true,
            "schema": {
              "type": "string"
            }
          }
        ],
        "requestBody": {
          "required": false,
          "content": {
            "application/json": {
              "schema": {
                "$ref": "#/components/schemas/UserUpdateRequest"
              },
              "examples": {
                "default": {
                  "summary": "UserUpdateRequest example",
                  "value": {
                    "name": "Ghani Khan",
                    "profilePicture": "https://example.com/profile.jpg"
                  }
                }
              }
            }
          }
        },
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/users/me/author-application": {
      "get": {
        "tags": [
          "Users"
        ],
        "summary": "Get current user author application",
        "description": "Get current user author application. Controller: authorApplicationController.getMyAuthorApplication. Authentication: Bearer. API routes are rate limited and return standard error envelopes.",
        "operationId": "get_api_users_me_author_application",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [],
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/users/{id}/orders/{orderId}/payments": {
      "get": {
        "tags": [
          "Users"
        ],
        "summary": "Get payment attempts for a user order",
        "description": "Get payment attempts for a user order. Controller: userController.getUserOrderPayments. Authentication: Bearer. API routes are rate limited and return standard error envelopes.",
        "operationId": "get_api_users_id_orders_orderId_payments",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [
          {
            "name": "id",
            "in": "path",
            "required": true,
            "schema": {
              "type": "string"
            }
          },
          {
            "name": "orderId",
            "in": "path",
            "required": true,
            "schema": {
              "type": "string"
            }
          },
          {
            "name": "page",
            "in": "query",
            "required": false,
            "schema": {
              "type": "integer",
              "minimum": 1,
              "default": 1
            }
          },
          {
            "name": "limit",
            "in": "query",
            "required": false,
            "schema": {
              "type": "integer",
              "minimum": 1,
              "maximum": 100,
              "default": 10
            }
          }
        ],
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/users/{id}/payments": {
      "get": {
        "tags": [
          "Users"
        ],
        "summary": "Get user payment attempts",
        "description": "Get user payment attempts. Controller: userController.getUserPayments. Authentication: Bearer. API routes are rate limited and return standard error envelopes.",
        "operationId": "get_api_users_id_payments",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [
          {
            "name": "id",
            "in": "path",
            "required": true,
            "schema": {
              "type": "string"
            }
          },
          {
            "name": "page",
            "in": "query",
            "required": false,
            "schema": {
              "type": "integer",
              "minimum": 1,
              "default": 1
            }
          },
          {
            "name": "limit",
            "in": "query",
            "required": false,
            "schema": {
              "type": "integer",
              "minimum": 1,
              "maximum": 100,
              "default": 10
            }
          },
          {
            "name": "status",
            "in": "query",
            "required": false,
            "schema": {
              "type": "string"
            }
          },
          {
            "name": "order",
            "in": "query",
            "required": false,
            "schema": {
              "type": "string"
            }
          }
        ],
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/users/{id}/payments/{paymentId}": {
      "get": {
        "tags": [
          "Users"
        ],
        "summary": "Get user payment detail including active QR metadata",
        "description": "Get user payment detail including active QR metadata. Controller: userController.getUserPayment. Authentication: Bearer. API routes are rate limited and return standard error envelopes.",
        "operationId": "get_api_users_id_payments_paymentId",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [
          {
            "name": "id",
            "in": "path",
            "required": true,
            "schema": {
              "type": "string"
            }
          },
          {
            "name": "paymentId",
            "in": "path",
            "required": true,
            "schema": {
              "type": "string"
            }
          }
        ],
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/users/{id}/invoices": {
      "get": {
        "tags": [
          "Users"
        ],
        "summary": "Get user invoices",
        "description": "Get user invoices. Controller: userController.getUserInvoices. Authentication: Bearer. API routes are rate limited and return standard error envelopes.",
        "operationId": "get_api_users_id_invoices",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [
          {
            "name": "id",
            "in": "path",
            "required": true,
            "schema": {
              "type": "string"
            }
          },
          {
            "name": "page",
            "in": "query",
            "required": false,
            "schema": {
              "type": "integer",
              "minimum": 1,
              "default": 1
            }
          },
          {
            "name": "limit",
            "in": "query",
            "required": false,
            "schema": {
              "type": "integer",
              "minimum": 1,
              "maximum": 100,
              "default": 10
            }
          },
          {
            "name": "status",
            "in": "query",
            "required": false,
            "schema": {
              "type": "string"
            }
          }
        ],
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/users/{id}/invoices/{invoiceId}": {
      "get": {
        "tags": [
          "Users"
        ],
        "summary": "Get user invoice",
        "description": "Get user invoice. Controller: userController.getUserInvoice. Authentication: Bearer. API routes are rate limited and return standard error envelopes.",
        "operationId": "get_api_users_id_invoices_invoiceId",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [
          {
            "name": "id",
            "in": "path",
            "required": true,
            "schema": {
              "type": "string"
            }
          },
          {
            "name": "invoiceId",
            "in": "path",
            "required": true,
            "schema": {
              "type": "string"
            }
          }
        ],
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/users/{id}/invoices/{invoiceId}/download": {
      "get": {
        "tags": [
          "Users"
        ],
        "summary": "Download user invoice",
        "description": "Download user invoice. Controller: userController.downloadUserInvoice. Authentication: Bearer. API routes are rate limited and return standard error envelopes.",
        "operationId": "get_api_users_id_invoices_invoiceId_download",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [
          {
            "name": "id",
            "in": "path",
            "required": true,
            "schema": {
              "type": "string"
            }
          },
          {
            "name": "invoiceId",
            "in": "path",
            "required": true,
            "schema": {
              "type": "string"
            }
          }
        ],
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/users/{id}/shipments": {
      "get": {
        "tags": [
          "Users"
        ],
        "summary": "Get user shipments",
        "description": "Get user shipments. Controller: userController.getUserShipments. Authentication: Bearer. API routes are rate limited and return standard error envelopes.",
        "operationId": "get_api_users_id_shipments",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [
          {
            "name": "id",
            "in": "path",
            "required": true,
            "schema": {
              "type": "string"
            }
          },
          {
            "name": "page",
            "in": "query",
            "required": false,
            "schema": {
              "type": "integer",
              "minimum": 1,
              "default": 1
            }
          },
          {
            "name": "limit",
            "in": "query",
            "required": false,
            "schema": {
              "type": "integer",
              "minimum": 1,
              "maximum": 100,
              "default": 10
            }
          },
          {
            "name": "status",
            "in": "query",
            "required": false,
            "schema": {
              "type": "string"
            }
          }
        ],
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/users/{id}/shipments/{shipmentId}": {
      "get": {
        "tags": [
          "Users"
        ],
        "summary": "Get user shipment detail",
        "description": "Get user shipment detail. Controller: userController.getUserShipment. Authentication: Bearer. API routes are rate limited and return standard error envelopes.",
        "operationId": "get_api_users_id_shipments_shipmentId",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [
          {
            "name": "id",
            "in": "path",
            "required": true,
            "schema": {
              "type": "string"
            }
          },
          {
            "name": "shipmentId",
            "in": "path",
            "required": true,
            "schema": {
              "type": "string"
            }
          }
        ],
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/users/{id}/notifications": {
      "get": {
        "tags": [
          "Users"
        ],
        "summary": "Get user notifications",
        "description": "Get user notifications. Controller: userController.getUserNotifications. Authentication: Bearer. API routes are rate limited and return standard error envelopes.",
        "operationId": "get_api_users_id_notifications",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [
          {
            "name": "id",
            "in": "path",
            "required": true,
            "schema": {
              "type": "string"
            }
          },
          {
            "name": "page",
            "in": "query",
            "required": false,
            "schema": {
              "type": "integer",
              "minimum": 1,
              "default": 1
            }
          },
          {
            "name": "limit",
            "in": "query",
            "required": false,
            "schema": {
              "type": "integer",
              "minimum": 1,
              "maximum": 100,
              "default": 10
            }
          },
          {
            "name": "status",
            "in": "query",
            "required": false,
            "schema": {
              "type": "string"
            }
          },
          {
            "name": "unread",
            "in": "query",
            "required": false,
            "schema": {
              "type": "string"
            }
          }
        ],
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/users/{id}/notifications/read-all": {
      "patch": {
        "tags": [
          "Users"
        ],
        "summary": "Mark all user notifications as read",
        "description": "Mark all user notifications as read. Controller: userController.markAllUserNotificationsRead. Authentication: Bearer. API routes are rate limited and return standard error envelopes.",
        "operationId": "patch_api_users_id_notifications_read_all",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [
          {
            "name": "id",
            "in": "path",
            "required": true,
            "schema": {
              "type": "string"
            }
          }
        ],
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/users/{id}/notifications/{notificationId}/read": {
      "patch": {
        "tags": [
          "Users"
        ],
        "summary": "Mark user notification as read",
        "description": "Mark user notification as read. Controller: userController.markUserNotificationRead. Authentication: Bearer. API routes are rate limited and return standard error envelopes.",
        "operationId": "patch_api_users_id_notifications_notificationId_read",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [
          {
            "name": "id",
            "in": "path",
            "required": true,
            "schema": {
              "type": "string"
            }
          },
          {
            "name": "notificationId",
            "in": "path",
            "required": true,
            "schema": {
              "type": "string"
            }
          }
        ],
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/users/{id}/notifications/{notificationId}": {
      "get": {
        "tags": [
          "Users"
        ],
        "summary": "Get user notification detail",
        "description": "Get user notification detail. Controller: userController.getUserNotification. Authentication: Bearer. API routes are rate limited and return standard error envelopes.",
        "operationId": "get_api_users_id_notifications_notificationId",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [
          {
            "name": "id",
            "in": "path",
            "required": true,
            "schema": {
              "type": "string"
            }
          },
          {
            "name": "notificationId",
            "in": "path",
            "required": true,
            "schema": {
              "type": "string"
            }
          }
        ],
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      },
      "delete": {
        "tags": [
          "Users"
        ],
        "summary": "Archive user notification",
        "description": "Archive user notification. Controller: userController.archiveUserNotification. Authentication: Bearer. API routes are rate limited and return standard error envelopes.",
        "operationId": "delete_api_users_id_notifications_notificationId",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [
          {
            "name": "id",
            "in": "path",
            "required": true,
            "schema": {
              "type": "string"
            }
          },
          {
            "name": "notificationId",
            "in": "path",
            "required": true,
            "schema": {
              "type": "string"
            }
          }
        ],
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/users/{id}/wishlist": {
      "get": {
        "tags": [
          "Users"
        ],
        "summary": "Get user wishlist",
        "description": "Get user wishlist. Controller: userController.getUserWishlist. Authentication: Bearer. API routes are rate limited and return standard error envelopes.",
        "operationId": "get_api_users_id_wishlist",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [
          {
            "name": "id",
            "in": "path",
            "required": true,
            "schema": {
              "type": "string"
            }
          }
        ],
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      },
      "post": {
        "tags": [
          "Users"
        ],
        "summary": "Add book to wishlist",
        "description": "Add book to wishlist. Controller: userController.addToWishlist. Authentication: Bearer. API routes are rate limited and return standard error envelopes.",
        "operationId": "post_api_users_id_wishlist",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [
          {
            "name": "id",
            "in": "path",
            "required": true,
            "schema": {
              "type": "string"
            }
          }
        ],
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {
                "$ref": "#/components/schemas/WishlistRequest"
              },
              "examples": {
                "default": {
                  "summary": "WishlistRequest example",
                  "value": {
                    "bookId": "66b4f5a2a44d2c0012a9c101"
                  }
                }
              }
            }
          }
        },
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/users/{id}/library": {
      "get": {
        "tags": [
          "Users"
        ],
        "summary": "Get user library",
        "description": "Get user library. Controller: userController.getUserLibrary. Authentication: Bearer. API routes are rate limited and return standard error envelopes.",
        "operationId": "get_api_users_id_library",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [
          {
            "name": "id",
            "in": "path",
            "required": true,
            "schema": {
              "type": "string"
            }
          }
        ],
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/users/{id}/wishlist/{bookId}": {
      "delete": {
        "tags": [
          "Users"
        ],
        "summary": "Remove book from wishlist",
        "description": "Remove book from wishlist. Controller: userController.removeFromWishlist. Authentication: Bearer. API routes are rate limited and return standard error envelopes.",
        "operationId": "delete_api_users_id_wishlist_bookId",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [
          {
            "name": "id",
            "in": "path",
            "required": true,
            "schema": {
              "type": "string"
            }
          },
          {
            "name": "bookId",
            "in": "path",
            "required": true,
            "schema": {
              "type": "string"
            }
          }
        ],
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/authors": {
      "get": {
        "tags": [
          "Authors"
        ],
        "summary": "List authors",
        "description": "List authors. Controller: authorController.getAuthors. Authentication: Public. API routes are rate limited and return standard error envelopes.",
        "operationId": "get_api_authors",
        "security": [],
        "parameters": [
          {
            "name": "page",
            "in": "query",
            "required": false,
            "schema": {
              "type": "integer",
              "minimum": 1,
              "default": 1
            }
          },
          {
            "name": "limit",
            "in": "query",
            "required": false,
            "schema": {
              "type": "integer",
              "minimum": 1,
              "maximum": 100,
              "default": 10
            }
          }
        ],
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/authors/{id}": {
      "get": {
        "tags": [
          "Authors"
        ],
        "summary": "Get author",
        "description": "Get author. Controller: authorController.getAuthorById. Authentication: Public. API routes are rate limited and return standard error envelopes.",
        "operationId": "get_api_authors_id",
        "security": [],
        "parameters": [
          {
            "name": "id",
            "in": "path",
            "required": true,
            "schema": {
              "type": "string"
            }
          }
        ],
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/authors/{id}/books": {
      "get": {
        "tags": [
          "Authors"
        ],
        "summary": "Get author books",
        "description": "Get author books. Controller: authorController.getAuthorBooks. Authentication: Public. API routes are rate limited and return standard error envelopes.",
        "operationId": "get_api_authors_id_books",
        "security": [],
        "parameters": [
          {
            "name": "id",
            "in": "path",
            "required": true,
            "schema": {
              "type": "string"
            }
          },
          {
            "name": "page",
            "in": "query",
            "required": false,
            "schema": {
              "type": "integer",
              "minimum": 1,
              "default": 1
            }
          },
          {
            "name": "limit",
            "in": "query",
            "required": false,
            "schema": {
              "type": "integer",
              "minimum": 1,
              "maximum": 100,
              "default": 10
            }
          },
          {
            "name": "sort",
            "in": "query",
            "required": false,
            "schema": {
              "type": "string"
            }
          }
        ],
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/authors/{id}/stats": {
      "get": {
        "tags": [
          "Authors"
        ],
        "summary": "Get author stats",
        "description": "Get author stats. Controller: authorController.getAuthorStats. Authentication: Bearer. API routes are rate limited and return standard error envelopes.",
        "operationId": "get_api_authors_id_stats",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [
          {
            "name": "id",
            "in": "path",
            "required": true,
            "schema": {
              "type": "string"
            }
          }
        ],
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/authors/{id}/analytics": {
      "get": {
        "tags": [
          "Authors"
        ],
        "summary": "Get author analytics alias",
        "description": "Get author analytics alias. Controller: authorController.getAuthorStats. Authentication: Bearer. API routes are rate limited and return standard error envelopes.",
        "operationId": "get_api_authors_id_analytics",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [
          {
            "name": "id",
            "in": "path",
            "required": true,
            "schema": {
              "type": "string"
            }
          }
        ],
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/authors/me/dashboard-access": {
      "get": {
        "tags": [
          "Author Access"
        ],
        "summary": "Get current author dashboard access status",
        "description": "Get current author dashboard access status. Controller: authorAccessController.getDashboardAccessStatus. Authentication: Author. API routes are rate limited and return standard error envelopes. Returns historical dashboard entitlement/purchase state and features.paidAuthorDashboardAccess. When the feature is false, approved authors can access dashboard without paid entitlement.",
        "operationId": "get_api_authors_me_dashboard_access",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [],
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/authors/me/dashboard-access/purchase": {
      "post": {
        "tags": [
          "Author Access"
        ],
        "summary": "Initiate author dashboard plan purchase",
        "description": "Initiate author dashboard plan purchase. Controller: authorAccessController.initiatePurchase. Authentication: Author. API routes are rate limited and return standard error envelopes. When AUTHOR_DASHBOARD_PAID_ACCESS_ENABLED=false, returns 409 AUTHOR_DASHBOARD_PAID_ACCESS_DISABLED and creates no purchase/payment.",
        "operationId": "post_api_authors_me_dashboard_access_purchase",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [],
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/authors/me/dashboard-access/purchases/{purchaseId}/verify-payment": {
      "put": {
        "tags": [
          "Author Access"
        ],
        "summary": "Submit UTR for author access purchase",
        "description": "Submit UTR for author access purchase. Controller: authorAccessController.submitPurchaseUTR. Authentication: Author. API routes are rate limited and return standard error envelopes.",
        "operationId": "put_api_authors_me_dashboard_access_purchases_purchaseId_verify_payment",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [
          {
            "name": "purchaseId",
            "in": "path",
            "required": true,
            "schema": {
              "type": "string"
            }
          }
        ],
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {
                "$ref": "#/components/schemas/PaymentVerificationRequest"
              },
              "examples": {
                "default": {
                  "summary": "PaymentVerificationRequest example",
                  "value": {
                    "utr": "UPI1234567890"
                  }
                }
              }
            }
          }
        },
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/authors/me/dashboard": {
      "get": {
        "tags": [
          "Author Dashboard"
        ],
        "summary": "Get authenticated author dashboard metrics summary",
        "description": "Get authenticated author dashboard metrics summary. Controller: authorController.getMyDashboard. Authentication: Author. API routes are rate limited and return standard error envelopes. Requires author role plus active entitlement when paid feature is enabled; author role alone when disabled. Admin always allowed.",
        "operationId": "get_api_authors_me_dashboard",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [],
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/authors/me/analytics": {
      "get": {
        "tags": [
          "Author Dashboard"
        ],
        "summary": "Get authenticated author sales time-series analytics",
        "description": "Get authenticated author sales time-series analytics. Controller: authorController.getMyAnalytics. Authentication: Author. API routes are rate limited and return standard error envelopes. Uses canonical author dashboard authorization gate.",
        "operationId": "get_api_authors_me_analytics",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [
          {
            "name": "range",
            "in": "query",
            "required": false,
            "schema": {
              "type": "string"
            }
          },
          {
            "name": "from",
            "in": "query",
            "required": false,
            "schema": {
              "type": "string",
              "format": "date-time"
            }
          },
          {
            "name": "to",
            "in": "query",
            "required": false,
            "schema": {
              "type": "string",
              "format": "date-time"
            }
          }
        ],
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/authors/me/books/performance": {
      "get": {
        "tags": [
          "Author Dashboard"
        ],
        "summary": "Get authenticated author book performance breakdown",
        "description": "Get authenticated author book performance breakdown. Controller: authorController.getMyBookPerformance. Authentication: Author. API routes are rate limited and return standard error envelopes. Uses canonical author dashboard authorization gate.",
        "operationId": "get_api_authors_me_books_performance",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [],
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/authors/me/royalties": {
      "get": {
        "tags": [
          "Author Dashboard"
        ],
        "summary": "Get authenticated author paginated royalty history",
        "description": "Get authenticated author paginated royalty history. Controller: authorController.getMyRoyalties. Authentication: Author. API routes are rate limited and return standard error envelopes. Uses canonical author dashboard authorization gate.",
        "operationId": "get_api_authors_me_royalties",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [
          {
            "name": "page",
            "in": "query",
            "required": false,
            "schema": {
              "type": "integer",
              "minimum": 1,
              "default": 1
            }
          },
          {
            "name": "limit",
            "in": "query",
            "required": false,
            "schema": {
              "type": "integer",
              "minimum": 1,
              "maximum": 100,
              "default": 10
            }
          },
          {
            "name": "bookId",
            "in": "query",
            "required": false,
            "schema": {
              "type": "string"
            }
          },
          {
            "name": "from",
            "in": "query",
            "required": false,
            "schema": {
              "type": "string",
              "format": "date-time"
            }
          },
          {
            "name": "to",
            "in": "query",
            "required": false,
            "schema": {
              "type": "string",
              "format": "date-time"
            }
          }
        ],
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/authors/me/books": {
      "get": {
        "tags": [
          "Author Publishing"
        ],
        "summary": "List author owned book drafts",
        "description": "List author owned book drafts. Controller: authorBookController.getMyBooks. Authentication: Author. API routes are rate limited and return standard error envelopes.",
        "operationId": "get_api_authors_me_books",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [
          {
            "name": "page",
            "in": "query",
            "required": false,
            "schema": {
              "type": "integer",
              "minimum": 1,
              "default": 1
            }
          },
          {
            "name": "limit",
            "in": "query",
            "required": false,
            "schema": {
              "type": "integer",
              "minimum": 1,
              "maximum": 100,
              "default": 10
            }
          },
          {
            "name": "status",
            "in": "query",
            "required": false,
            "schema": {
              "type": "string"
            }
          },
          {
            "name": "search",
            "in": "query",
            "required": false,
            "schema": {
              "type": "string"
            }
          },
          {
            "name": "sort",
            "in": "query",
            "required": false,
            "schema": {
              "type": "string"
            }
          }
        ],
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      },
      "post": {
        "tags": [
          "Author Publishing"
        ],
        "summary": "Create author book draft",
        "description": "Create author book draft. Controller: authorBookController.createBookDraft. Authentication: Author. API routes are rate limited and return standard error envelopes. Author-owned draft payload only. Book.mrp is canonical; legacy price is accepted only as a synchronized compatibility alias.",
        "operationId": "post_api_authors_me_books",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [],
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {
                "$ref": "#/components/schemas/AuthorBookCreateRequest"
              },
              "examples": {
                "default": {
                  "summary": "AuthorBookCreateRequest example",
                  "value": {
                    "title": "My Publishing Journey",
                    "description": "A draft manuscript prepared by the authenticated author.",
                    "category": "66b4f5a2a44d2c0012a9c102",
                    "mrp": 399,
                    "coverImage": "https://example.com/cover.jpg",
                    "pages": 240,
                    "format": "paperback"
                  }
                }
              }
            }
          }
        },
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/authors/me/books/{bookId}": {
      "get": {
        "tags": [
          "Author Publishing"
        ],
        "summary": "Get author owned book detail",
        "description": "Get author owned book detail. Controller: authorBookController.getMyBookDetail. Authentication: Author. API routes are rate limited and return standard error envelopes.",
        "operationId": "get_api_authors_me_books_bookId",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [
          {
            "name": "bookId",
            "in": "path",
            "required": true,
            "schema": {
              "type": "string"
            }
          }
        ],
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      },
      "put": {
        "tags": [
          "Author Publishing"
        ],
        "summary": "Update author book draft",
        "description": "Update author book draft. Controller: authorBookController.updateBookDraft. Authentication: Author. API routes are rate limited and return standard error envelopes. Author may update only allowlisted draft fields. Admin-only fields are rejected.",
        "operationId": "put_api_authors_me_books_bookId",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [
          {
            "name": "bookId",
            "in": "path",
            "required": true,
            "schema": {
              "type": "string"
            }
          }
        ],
        "requestBody": {
          "required": false,
          "content": {
            "application/json": {
              "schema": {
                "$ref": "#/components/schemas/AuthorBookUpdateRequest"
              },
              "examples": {
                "default": {
                  "summary": "AuthorBookUpdateRequest example",
                  "value": {
                    "title": "My Updated Publishing Journey",
                    "mrp": 449,
                    "pages": 260
                  }
                }
              }
            }
          }
        },
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      },
      "delete": {
        "tags": [
          "Author Publishing"
        ],
        "summary": "Delete author book draft",
        "description": "Delete author book draft. Controller: authorBookController.deleteBookDraft. Authentication: Author. API routes are rate limited and return standard error envelopes.",
        "operationId": "delete_api_authors_me_books_bookId",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [
          {
            "name": "bookId",
            "in": "path",
            "required": true,
            "schema": {
              "type": "string"
            }
          }
        ],
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/authors/me/books/{bookId}/submit": {
      "post": {
        "tags": [
          "Author Publishing"
        ],
        "summary": "Submit author book for editorial review",
        "description": "Submit author book for editorial review. Controller: authorBookController.submitBookForReview. Authentication: Author. API routes are rate limited and return standard error envelopes.",
        "operationId": "post_api_authors_me_books_bookId_submit",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [
          {
            "name": "bookId",
            "in": "path",
            "required": true,
            "schema": {
              "type": "string"
            }
          }
        ],
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {
                "$ref": "#/components/schemas/BookSubmissionRequest"
              },
              "examples": {
                "default": {
                  "summary": "BookSubmissionRequest example",
                  "value": {
                    "fileUrl": "https://res.cloudinary.com/demo/raw/upload/manuscript.pdf",
                    "packageId": "66b4f5a2a44d2c0012a9c104",
                    "genre": "Business",
                    "wordCount": 52000
                  }
                }
              }
            }
          }
        },
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/authors/me/uploads/document": {
      "post": {
        "tags": [
          "Author Publishing"
        ],
        "summary": "Upload author manuscript document",
        "description": "Upload author manuscript document. Controller: uploadController.uploadDocument. Authentication: Author. API routes are rate limited and return standard error envelopes. Multipart field: document. Allowed: pdf, doc, docx. Default max size: 25MB. Requires Cloudinary configuration.",
        "operationId": "post_api_authors_me_uploads_document",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [],
        "requestBody": {
          "required": true,
          "content": {
            "multipart/form-data": {
              "schema": {
                "$ref": "#/components/schemas/MultipartDocumentRequest"
              }
            }
          }
        },
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/authors/me/uploads/image": {
      "post": {
        "tags": [
          "Author Publishing"
        ],
        "summary": "Upload author book cover image",
        "description": "Upload author book cover image. Controller: uploadController.uploadImage. Authentication: Author. API routes are rate limited and return standard error envelopes. Multipart field: image. Allowed: jpg, jpeg, png, webp, gif. Default max size: 25MB. Requires Cloudinary configuration.",
        "operationId": "post_api_authors_me_uploads_image",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [],
        "requestBody": {
          "required": true,
          "content": {
            "multipart/form-data": {
              "schema": {
                "$ref": "#/components/schemas/MultipartImageRequest"
              }
            }
          }
        },
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/uploads/publishing-document": {
      "post": {
        "tags": [
          "Uploads"
        ],
        "summary": "Upload publishing manuscript document",
        "description": "Upload publishing manuscript document. Controller: uploadController.uploadDocument. Authentication: Author/Admin. API routes are rate limited and return standard error envelopes. Multipart field: document. Allowed: pdf, doc, docx. Default max size: 25MB. Requires Cloudinary configuration.",
        "operationId": "post_api_uploads_publishing_document",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [],
        "requestBody": {
          "required": true,
          "content": {
            "multipart/form-data": {
              "schema": {
                "$ref": "#/components/schemas/MultipartDocumentRequest"
              }
            }
          }
        },
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {
                        "url": "https://res.cloudinary.com/demo/image/upload/sample.jpg",
                        "public_id": "hm_uploads/sample"
                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {
                        "url": "https://res.cloudinary.com/demo/image/upload/sample.jpg",
                        "public_id": "hm_uploads/sample"
                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "503": {
            "$ref": "#/components/responses/ServiceUnavailable"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/uploads/publishing-image": {
      "post": {
        "tags": [
          "Uploads"
        ],
        "summary": "Upload publishing cover image",
        "description": "Upload publishing cover image. Controller: uploadController.uploadImage. Authentication: Author/Admin. API routes are rate limited and return standard error envelopes. Multipart field: image. Allowed: jpg, jpeg, png, webp, gif. Default max size: 25MB. Requires Cloudinary configuration.",
        "operationId": "post_api_uploads_publishing_image",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [],
        "requestBody": {
          "required": true,
          "content": {
            "multipart/form-data": {
              "schema": {
                "$ref": "#/components/schemas/MultipartImageRequest"
              }
            }
          }
        },
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {
                        "url": "https://res.cloudinary.com/demo/image/upload/sample.jpg",
                        "public_id": "hm_uploads/sample"
                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {
                        "url": "https://res.cloudinary.com/demo/image/upload/sample.jpg",
                        "public_id": "hm_uploads/sample"
                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "503": {
            "$ref": "#/components/responses/ServiceUnavailable"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/publish-requests": {
      "post": {
        "tags": [
          "Publishing"
        ],
        "summary": "Create publish request",
        "description": "Create publish request. Controller: publishController.createPublishRequest. Authentication: Author/Admin. API routes are rate limited and return standard error envelopes.",
        "operationId": "post_api_publish_requests",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [],
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {
                "$ref": "#/components/schemas/PublishRequestCreate"
              },
              "examples": {
                "default": {
                  "summary": "PublishRequestCreate example",
                  "value": {
                    "title": "My Manuscript",
                    "genre": "Business",
                    "wordCount": 65000,
                    "packageId": "66b4f5a2a44d2c0012a9c104",
                    "fileUrl": "https://res.cloudinary.com/demo/raw/upload/manuscript.pdf"
                  }
                }
              }
            }
          }
        },
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/publish-packages": {
      "get": {
        "tags": [
          "Publishing"
        ],
        "summary": "List publish packages",
        "description": "List publish packages. Controller: publishController.getPublishPackages. Authentication: Public. API routes are rate limited and return standard error envelopes.",
        "operationId": "get_api_publish_packages",
        "security": [],
        "parameters": [],
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/admin/analytics": {
      "get": {
        "tags": [
          "Admin Core"
        ],
        "summary": "Admin analytics summary",
        "description": "Admin analytics summary. Controller: adminController.getAdminAnalytics. Authentication: Admin. API routes are rate limited and return standard error envelopes.",
        "operationId": "get_api_admin_analytics",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [],
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/admin/reviews": {
      "get": {
        "tags": [
          "Admin Core"
        ],
        "summary": "List reviews for moderation",
        "description": "List reviews for moderation. Controller: reviewController.listReviews. Authentication: Admin. API routes are rate limited and return standard error envelopes.",
        "operationId": "get_api_admin_reviews",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [
          {
            "name": "page",
            "in": "query",
            "required": false,
            "schema": {
              "type": "integer",
              "minimum": 1,
              "default": 1
            }
          },
          {
            "name": "limit",
            "in": "query",
            "required": false,
            "schema": {
              "type": "integer",
              "minimum": 1,
              "maximum": 100,
              "default": 10
            }
          },
          {
            "name": "status",
            "in": "query",
            "required": false,
            "schema": {
              "type": "string"
            }
          },
          {
            "name": "book",
            "in": "query",
            "required": false,
            "schema": {
              "type": "string"
            }
          },
          {
            "name": "user",
            "in": "query",
            "required": false,
            "schema": {
              "type": "string"
            }
          }
        ],
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/admin/reviews/{id}/status": {
      "patch": {
        "tags": [
          "Admin Core"
        ],
        "summary": "Moderate review",
        "description": "Moderate review. Controller: reviewController.moderateReview. Authentication: Admin. API routes are rate limited and return standard error envelopes.",
        "operationId": "patch_api_admin_reviews_id_status",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [
          {
            "name": "id",
            "in": "path",
            "required": true,
            "schema": {
              "type": "string"
            }
          }
        ],
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {
                "$ref": "#/components/schemas/ReviewModerationRequest"
              },
              "examples": {
                "default": {
                  "summary": "ReviewModerationRequest example",
                  "value": {
                    "type": "object",
                    "required": [
                      "status"
                    ],
                    "properties": {
                      "status": {
                        "type": "string",
                        "enum": [
                          "approved",
                          "pending",
                          "rejected"
                        ]
                      }
                    }
                  }
                }
              }
            }
          }
        },
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/admin/reviews/{id}": {
      "delete": {
        "tags": [
          "Admin Core"
        ],
        "summary": "Delete review as admin",
        "description": "Delete review as admin. Controller: reviewController.deleteReview. Authentication: Admin. API routes are rate limited and return standard error envelopes.",
        "operationId": "delete_api_admin_reviews_id",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [
          {
            "name": "id",
            "in": "path",
            "required": true,
            "schema": {
              "type": "string"
            }
          }
        ],
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/admin/content": {
      "put": {
        "tags": [
          "Admin Content"
        ],
        "summary": "Update global CMS content",
        "description": "Update global CMS content. Controller: contentController.updateContent. Authentication: Admin. API routes are rate limited and return standard error envelopes.",
        "operationId": "put_api_admin_content",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [],
        "requestBody": {
          "required": false,
          "content": {
            "application/json": {
              "schema": {
                "$ref": "#/components/schemas/ContentUpdateRequest"
              },
              "examples": {
                "default": {
                  "summary": "ContentUpdateRequest example",
                  "value": {
                    "type": "object",
                    "properties": {
                      "hero": {
                        "type": "object",
                        "additionalProperties": true
                      },
                      "about": {
                        "type": "object",
                        "additionalProperties": true
                      },
                      "contact": {
                        "type": "object",
                        "additionalProperties": true
                      },
                      "faq": {
                        "type": "array",
                        "items": {
                          "type": "object",
                          "additionalProperties": true
                        }
                      },
                      "footer": {
                        "type": "object",
                        "additionalProperties": true
                      },
                      "socialLinks": {
                        "type": "object",
                        "additionalProperties": true
                      },
                      "seo": {
                        "type": "object",
                        "additionalProperties": true
                      },
                      "announcements": {
                        "type": "array",
                        "items": {
                          "type": "object",
                          "additionalProperties": true
                        }
                      },
                      "siteSettings": {
                        "type": "object",
                        "additionalProperties": true
                      },
                      "homeTitle": {
                        "type": "string"
                      },
                      "homeSubtitle": {
                        "type": "string"
                      },
                      "publishTitle": {
                        "type": "string"
                      },
                      "publishSubtitle": {
                        "type": "string"
                      },
                      "packagesJson": {
                        "type": "string"
                      }
                    }
                  }
                }
              }
            }
          }
        },
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/admin/users": {
      "get": {
        "tags": [
          "Admin Users"
        ],
        "summary": "List users",
        "description": "List users. Controller: adminController.listUsers. Authentication: Admin. API routes are rate limited and return standard error envelopes.",
        "operationId": "get_api_admin_users",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [
          {
            "name": "page",
            "in": "query",
            "required": false,
            "schema": {
              "type": "integer",
              "minimum": 1,
              "default": 1
            }
          },
          {
            "name": "limit",
            "in": "query",
            "required": false,
            "schema": {
              "type": "integer",
              "minimum": 1,
              "maximum": 100,
              "default": 10
            }
          },
          {
            "name": "role",
            "in": "query",
            "required": false,
            "schema": {
              "type": "string"
            }
          },
          {
            "name": "isActive",
            "in": "query",
            "required": false,
            "schema": {
              "type": "string"
            }
          },
          {
            "name": "search",
            "in": "query",
            "required": false,
            "schema": {
              "type": "string"
            }
          }
        ],
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/admin/users/{id}": {
      "get": {
        "tags": [
          "Admin Users"
        ],
        "summary": "Get user",
        "description": "Get user. Controller: adminController.getUser. Authentication: Admin. API routes are rate limited and return standard error envelopes.",
        "operationId": "get_api_admin_users_id",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [
          {
            "name": "id",
            "in": "path",
            "required": true,
            "schema": {
              "type": "string"
            }
          }
        ],
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      },
      "put": {
        "tags": [
          "Admin Users"
        ],
        "summary": "Update user",
        "description": "Update user. Controller: adminController.updateUser. Authentication: Admin. API routes are rate limited and return standard error envelopes.",
        "operationId": "put_api_admin_users_id",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [
          {
            "name": "id",
            "in": "path",
            "required": true,
            "schema": {
              "type": "string"
            }
          }
        ],
        "requestBody": {
          "required": false,
          "content": {
            "application/json": {
              "schema": {
                "$ref": "#/components/schemas/AdminUserUpdateRequest"
              },
              "examples": {
                "default": {
                  "summary": "AdminUserUpdateRequest example",
                  "value": {
                    "type": "object",
                    "properties": {
                      "role": {
                        "type": "string",
                        "enum": [
                          "user",
                          "visitor",
                          "reader",
                          "author",
                          "admin"
                        ],
                        "description": "user is normalized to reader."
                      },
                      "isActive": {
                        "type": "boolean"
                      },
                      "status": {
                        "type": "string",
                        "enum": [
                          "Active",
                          "Suspended"
                        ],
                        "description": "Frontend compatibility alias for isActive."
                      }
                    }
                  }
                }
              }
            }
          }
        },
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/admin/users/{id}/role": {
      "patch": {
        "tags": [
          "Admin Users"
        ],
        "summary": "Update user role",
        "description": "Update user role. Controller: adminController.updateUserRole. Authentication: Admin. API routes are rate limited and return standard error envelopes.",
        "operationId": "patch_api_admin_users_id_role",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [
          {
            "name": "id",
            "in": "path",
            "required": true,
            "schema": {
              "type": "string"
            }
          }
        ],
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {
                "$ref": "#/components/schemas/UserRoleRequest"
              },
              "examples": {
                "default": {
                  "summary": "UserRoleRequest example",
                  "value": {
                    "type": "object",
                    "required": [
                      "role"
                    ],
                    "properties": {
                      "role": {
                        "type": "string",
                        "enum": [
                          "user",
                          "visitor",
                          "reader",
                          "author",
                          "admin"
                        ],
                        "description": "user is normalized to reader for frontend compatibility."
                      }
                    }
                  }
                }
              }
            }
          }
        },
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      },
      "put": {
        "tags": [
          "Admin Users"
        ],
        "summary": "Update user role alias",
        "description": "Update user role alias. Controller: adminController.updateUserRole. Authentication: Admin. API routes are rate limited and return standard error envelopes.",
        "operationId": "put_api_admin_users_id_role",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [
          {
            "name": "id",
            "in": "path",
            "required": true,
            "schema": {
              "type": "string"
            }
          }
        ],
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {
                "$ref": "#/components/schemas/UserRoleRequest"
              },
              "examples": {
                "default": {
                  "summary": "UserRoleRequest example",
                  "value": {
                    "type": "object",
                    "required": [
                      "role"
                    ],
                    "properties": {
                      "role": {
                        "type": "string",
                        "enum": [
                          "user",
                          "visitor",
                          "reader",
                          "author",
                          "admin"
                        ],
                        "description": "user is normalized to reader for frontend compatibility."
                      }
                    }
                  }
                }
              }
            }
          }
        },
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/admin/users/{id}/status": {
      "patch": {
        "tags": [
          "Admin Users"
        ],
        "summary": "Update user active status",
        "description": "Update user active status. Controller: adminController.updateUserStatus. Authentication: Admin. API routes are rate limited and return standard error envelopes.",
        "operationId": "patch_api_admin_users_id_status",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [
          {
            "name": "id",
            "in": "path",
            "required": true,
            "schema": {
              "type": "string"
            }
          }
        ],
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {
                "$ref": "#/components/schemas/UserStatusRequest"
              },
              "examples": {
                "default": {
                  "summary": "UserStatusRequest example",
                  "value": {
                    "type": "object",
                    "required": [
                      "isActive"
                    ],
                    "properties": {
                      "isActive": {
                        "type": "boolean"
                      }
                    }
                  }
                }
              }
            }
          }
        },
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/admin/users/{id}/reset-password": {
      "post": {
        "tags": [
          "Admin Users"
        ],
        "summary": "Reset user password",
        "description": "Reset user password. Controller: adminController.resetUserPassword. Authentication: Admin. API routes are rate limited and return standard error envelopes.",
        "operationId": "post_api_admin_users_id_reset_password",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [
          {
            "name": "id",
            "in": "path",
            "required": true,
            "schema": {
              "type": "string"
            }
          }
        ],
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {
                "$ref": "#/components/schemas/ResetPasswordRequest"
              },
              "examples": {
                "default": {
                  "summary": "ResetPasswordRequest example",
                  "value": {
                    "type": "object",
                    "required": [
                      "password"
                    ],
                    "properties": {
                      "password": {
                        "type": "string",
                        "minLength": 6
                      }
                    }
                  }
                }
              }
            }
          }
        },
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/admin/orders": {
      "get": {
        "tags": [
          "Admin Core"
        ],
        "summary": "List orders",
        "description": "List orders. Controller: adminController.getOrders. Authentication: Admin. API routes are rate limited and return standard error envelopes.",
        "operationId": "get_api_admin_orders",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [],
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/admin/orders/{id}/status": {
      "put": {
        "tags": [
          "Admin Core"
        ],
        "summary": "Update order status",
        "description": "Update order status. Controller: adminController.updateOrderStatus. Authentication: Admin. API routes are rate limited and return standard error envelopes.",
        "operationId": "put_api_admin_orders_id_status",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [
          {
            "name": "id",
            "in": "path",
            "required": true,
            "schema": {
              "type": "string"
            }
          }
        ],
        "requestBody": {
          "required": false,
          "content": {
            "application/json": {
              "schema": {
                "$ref": "#/components/schemas/StatusUpdateRequest"
              },
              "examples": {
                "default": {
                  "summary": "StatusUpdateRequest example",
                  "value": {
                    "status": "Processing",
                    "reason": "Status updated by admin"
                  }
                }
              }
            }
          }
        },
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/admin/publish-requests": {
      "get": {
        "tags": [
          "Admin Core"
        ],
        "summary": "List publish requests",
        "description": "List publish requests. Controller: adminController.getPublishRequests. Authentication: Admin. API routes are rate limited and return standard error envelopes.",
        "operationId": "get_api_admin_publish_requests",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [],
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/admin/publish-requests/{id}/status": {
      "put": {
        "tags": [
          "Admin Core"
        ],
        "summary": "Update publish request status",
        "description": "Update publish request status. Controller: adminController.updatePublishRequestStatus. Authentication: Admin. API routes are rate limited and return standard error envelopes.",
        "operationId": "put_api_admin_publish_requests_id_status",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [
          {
            "name": "id",
            "in": "path",
            "required": true,
            "schema": {
              "type": "string"
            }
          }
        ],
        "requestBody": {
          "required": false,
          "content": {
            "application/json": {
              "schema": {
                "$ref": "#/components/schemas/StatusUpdateRequest"
              },
              "examples": {
                "default": {
                  "summary": "StatusUpdateRequest example",
                  "value": {
                    "status": "Processing",
                    "reason": "Status updated by admin"
                  }
                }
              }
            }
          }
        },
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/admin/publish-requests/{id}/request-changes": {
      "post": {
        "tags": [
          "Admin Core"
        ],
        "summary": "Request changes on publish request",
        "description": "Request changes on publish request. Controller: adminController.requestChangesOnPublishRequest. Authentication: Admin. API routes are rate limited and return standard error envelopes.",
        "operationId": "post_api_admin_publish_requests_id_request_changes",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [
          {
            "name": "id",
            "in": "path",
            "required": true,
            "schema": {
              "type": "string"
            }
          }
        ],
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {
                "$ref": "#/components/schemas/EditorialReasonRequest"
              },
              "examples": {
                "default": {
                  "summary": "EditorialReasonRequest example",
                  "value": {
                    "reason": "Please upload a higher-resolution cover image."
                  }
                }
              }
            }
          }
        },
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/admin/publish-requests/{id}/reject": {
      "post": {
        "tags": [
          "Admin Core"
        ],
        "summary": "Reject publish request",
        "description": "Reject publish request. Controller: adminController.rejectPublishRequest. Authentication: Admin. API routes are rate limited and return standard error envelopes.",
        "operationId": "post_api_admin_publish_requests_id_reject",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [
          {
            "name": "id",
            "in": "path",
            "required": true,
            "schema": {
              "type": "string"
            }
          }
        ],
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {
                "$ref": "#/components/schemas/EditorialReasonRequest"
              },
              "examples": {
                "default": {
                  "summary": "EditorialReasonRequest example",
                  "value": {
                    "reason": "Please upload a higher-resolution cover image."
                  }
                }
              }
            }
          }
        },
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/admin/publish-requests/{id}/approve": {
      "post": {
        "tags": [
          "Admin Core"
        ],
        "summary": "Approve publish request and publish book",
        "description": "Approve publish request and publish book. Controller: adminController.approveAndPublishBook. Authentication: Admin. API routes are rate limited and return standard error envelopes.",
        "operationId": "post_api_admin_publish_requests_id_approve",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [
          {
            "name": "id",
            "in": "path",
            "required": true,
            "schema": {
              "type": "string"
            }
          }
        ],
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {
                "$ref": "#/components/schemas/EditorialNotesRequest"
              },
              "examples": {
                "default": {
                  "summary": "EditorialNotesRequest example",
                  "value": {
                    "notes": "Approved after editorial review."
                  }
                }
              }
            }
          }
        },
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/admin/books": {
      "get": {
        "tags": [
          "Admin Core"
        ],
        "summary": "List books",
        "description": "List books. Controller: adminController.listBooks. Authentication: Admin. API routes are rate limited and return standard error envelopes. Admin inventory list. Returns draft, published, and archived books unless filtered. Supports pagination, search, and safe sort fields.",
        "operationId": "get_api_admin_books",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [
          {
            "name": "page",
            "in": "query",
            "required": false,
            "schema": {
              "type": "integer",
              "minimum": 1,
              "default": 1
            }
          },
          {
            "name": "limit",
            "in": "query",
            "required": false,
            "schema": {
              "type": "integer",
              "minimum": 1,
              "maximum": 100,
              "default": 10
            }
          },
          {
            "name": "status",
            "in": "query",
            "required": false,
            "schema": {
              "type": "string"
            }
          },
          {
            "name": "category",
            "in": "query",
            "required": false,
            "schema": {
              "type": "string"
            }
          },
          {
            "name": "author",
            "in": "query",
            "required": false,
            "schema": {
              "type": "string"
            }
          },
          {
            "name": "search",
            "in": "query",
            "required": false,
            "schema": {
              "type": "string"
            }
          },
          {
            "name": "q",
            "in": "query",
            "required": false,
            "schema": {
              "type": "string"
            }
          },
          {
            "name": "sort",
            "in": "query",
            "required": false,
            "schema": {
              "type": "string"
            }
          },
          {
            "name": "isFeatured",
            "in": "query",
            "required": false,
            "schema": {
              "type": "string"
            }
          },
          {
            "name": "isBestseller",
            "in": "query",
            "required": false,
            "schema": {
              "type": "string"
            }
          },
          {
            "name": "isNewRelease",
            "in": "query",
            "required": false,
            "schema": {
              "type": "string"
            }
          }
        ],
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      },
      "post": {
        "tags": [
          "Admin Core"
        ],
        "summary": "Create book",
        "description": "Create book. Controller: adminController.createBook. Authentication: Admin. API routes are rate limited and return standard error envelopes. Book.slug is server-owned and generated from title. Book.mrp is canonical. Legacy price is accepted temporarily only as a synchronized compatibility alias.",
        "operationId": "post_api_admin_books",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [],
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {
                "$ref": "#/components/schemas/AdminBookCreateRequest"
              },
              "examples": {
                "default": {
                  "summary": "AdminBookCreateRequest example",
                  "value": {
                    "title": "Enterprise Publishing Systems",
                    "description": "A practical book about modern publishing operations.",
                    "category": "66b4f5a2a44d2c0012a9c102",
                    "author": "66b4f5a2a44d2c0012a9c103",
                    "mrp": 499,
                    "royaltyPercentage": 10,
                    "coverImage": "https://example.com/cover.jpg",
                    "stock": 100,
                    "status": "published",
                    "discountPrice": 399,
                    "isFeatured": true,
                    "isbn": "9781234567890",
                    "pages": 320,
                    "format": "paperback"
                  }
                }
              }
            }
          }
        },
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/admin/books/{id}": {
      "put": {
        "tags": [
          "Admin Core"
        ],
        "summary": "Update book",
        "description": "Update book. Controller: adminController.updateBook. Authentication: Admin. API routes are rate limited and return standard error envelopes. Book.mrp is canonical. If both mrp and legacy price are supplied, they must match.",
        "operationId": "put_api_admin_books_id",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [
          {
            "name": "id",
            "in": "path",
            "required": true,
            "schema": {
              "type": "string"
            }
          }
        ],
        "requestBody": {
          "required": false,
          "content": {
            "application/json": {
              "schema": {
                "$ref": "#/components/schemas/AdminBookUpdateRequest"
              },
              "examples": {
                "default": {
                  "summary": "AdminBookUpdateRequest example",
                  "value": {
                    "mrp": 449,
                    "royaltyPercentage": 12,
                    "stock": 120,
                    "status": "published",
                    "isBestseller": true
                  }
                }
              }
            }
          }
        },
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      },
      "delete": {
        "tags": [
          "Admin Core"
        ],
        "summary": "Delete book",
        "description": "Delete book. Controller: adminController.deleteBook. Authentication: Admin. API routes are rate limited and return standard error envelopes.",
        "operationId": "delete_api_admin_books_id",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [
          {
            "name": "id",
            "in": "path",
            "required": true,
            "schema": {
              "type": "string"
            }
          }
        ],
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/admin/categories": {
      "get": {
        "tags": [
          "Admin Categories"
        ],
        "summary": "List categories",
        "description": "List categories. Controller: categoryController.listAdminCategories. Authentication: Admin. API routes are rate limited and return standard error envelopes. Admin list can include inactive categories when active=false is supplied.",
        "operationId": "get_api_admin_categories",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [
          {
            "name": "page",
            "in": "query",
            "required": false,
            "schema": {
              "type": "integer",
              "minimum": 1,
              "default": 1
            }
          },
          {
            "name": "limit",
            "in": "query",
            "required": false,
            "schema": {
              "type": "integer",
              "minimum": 1,
              "maximum": 100,
              "default": 10
            }
          },
          {
            "name": "featured",
            "in": "query",
            "required": false,
            "schema": {
              "type": "boolean"
            }
          },
          {
            "name": "active",
            "in": "query",
            "required": false,
            "schema": {
              "type": "boolean"
            }
          },
          {
            "name": "search",
            "in": "query",
            "required": false,
            "schema": {
              "type": "string"
            }
          },
          {
            "name": "sort",
            "in": "query",
            "required": false,
            "schema": {
              "type": "string"
            }
          }
        ],
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {
                        "_id": "66b4f5a2a44d2c0012a9c102",
                        "name": "Business Books",
                        "slug": "business-books",
                        "active": true,
                        "featured": true,
                        "bookCount": 12
                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {
                        "_id": "66b4f5a2a44d2c0012a9c102",
                        "name": "Business Books",
                        "slug": "business-books",
                        "active": true,
                        "featured": true,
                        "bookCount": 12
                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "409": {
            "$ref": "#/components/responses/Conflict"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      },
      "post": {
        "tags": [
          "Admin Categories"
        ],
        "summary": "Create category",
        "description": "Create category. Controller: categoryController.createCategory. Authentication: Admin. API routes are rate limited and return standard error envelopes. Name and slug must be unique. Slug is generated from name when omitted.",
        "operationId": "post_api_admin_categories",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [],
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {
                "$ref": "#/components/schemas/CategoryCreateRequest"
              },
              "examples": {
                "default": {
                  "summary": "CategoryCreateRequest example",
                  "value": {
                    "name": "Business Books",
                    "description": "Books for founders, operators, and enterprise teams.",
                    "shortDescription": "Business and operations titles.",
                    "featured": true,
                    "sortOrder": 10,
                    "seoTitle": "Business Books",
                    "seoDescription": "Business books from Harglim Publishers."
                  }
                }
              }
            }
          }
        },
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {
                        "_id": "66b4f5a2a44d2c0012a9c102",
                        "name": "Business Books",
                        "slug": "business-books",
                        "active": true,
                        "featured": true,
                        "bookCount": 12
                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {
                        "_id": "66b4f5a2a44d2c0012a9c102",
                        "name": "Business Books",
                        "slug": "business-books",
                        "active": true,
                        "featured": true,
                        "bookCount": 12
                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "409": {
            "$ref": "#/components/responses/Conflict"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/admin/categories/{id}": {
      "get": {
        "tags": [
          "Admin Categories"
        ],
        "summary": "Get category",
        "description": "Get category. Controller: categoryController.getAdminCategory. Authentication: Admin. API routes are rate limited and return standard error envelopes.",
        "operationId": "get_api_admin_categories_id",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [
          {
            "name": "id",
            "in": "path",
            "required": true,
            "schema": {
              "type": "string"
            }
          }
        ],
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {
                        "_id": "66b4f5a2a44d2c0012a9c102",
                        "name": "Business Books",
                        "slug": "business-books",
                        "active": true,
                        "featured": true,
                        "bookCount": 12
                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {
                        "_id": "66b4f5a2a44d2c0012a9c102",
                        "name": "Business Books",
                        "slug": "business-books",
                        "active": true,
                        "featured": true,
                        "bookCount": 12
                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "409": {
            "$ref": "#/components/responses/Conflict"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      },
      "put": {
        "tags": [
          "Admin Categories"
        ],
        "summary": "Update category",
        "description": "Update category. Controller: categoryController.updateCategory. Authentication: Admin. API routes are rate limited and return standard error envelopes. bookCount is managed by the system and cannot be set through this payload.",
        "operationId": "put_api_admin_categories_id",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [
          {
            "name": "id",
            "in": "path",
            "required": true,
            "schema": {
              "type": "string"
            }
          }
        ],
        "requestBody": {
          "required": false,
          "content": {
            "application/json": {
              "schema": {
                "$ref": "#/components/schemas/CategoryUpdateRequest"
              },
              "examples": {
                "default": {
                  "summary": "CategoryUpdateRequest example",
                  "value": {
                    "description": "Updated category description.",
                    "featured": false,
                    "sortOrder": 20
                  }
                }
              }
            }
          }
        },
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {
                        "_id": "66b4f5a2a44d2c0012a9c102",
                        "name": "Business Books",
                        "slug": "business-books",
                        "active": true,
                        "featured": true,
                        "bookCount": 12
                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {
                        "_id": "66b4f5a2a44d2c0012a9c102",
                        "name": "Business Books",
                        "slug": "business-books",
                        "active": true,
                        "featured": true,
                        "bookCount": 12
                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "409": {
            "$ref": "#/components/responses/Conflict"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      },
      "delete": {
        "tags": [
          "Admin Categories"
        ],
        "summary": "Soft delete category",
        "description": "Soft delete category. Controller: categoryController.deleteCategory. Authentication: Admin. API routes are rate limited and return standard error envelopes. Soft delete only. Categories with active books return 409 conflict.",
        "operationId": "delete_api_admin_categories_id",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [
          {
            "name": "id",
            "in": "path",
            "required": true,
            "schema": {
              "type": "string"
            }
          }
        ],
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {
                        "_id": "66b4f5a2a44d2c0012a9c102",
                        "name": "Business Books",
                        "slug": "business-books",
                        "active": true,
                        "featured": true,
                        "bookCount": 12
                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {
                        "_id": "66b4f5a2a44d2c0012a9c102",
                        "name": "Business Books",
                        "slug": "business-books",
                        "active": true,
                        "featured": true,
                        "bookCount": 12
                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "409": {
            "$ref": "#/components/responses/Conflict"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/admin/categories/{id}/status": {
      "patch": {
        "tags": [
          "Admin Categories"
        ],
        "summary": "Update category status",
        "description": "Update category status. Controller: categoryController.updateCategoryStatus. Authentication: Admin. API routes are rate limited and return standard error envelopes. Synchronizes active and legacy isActive fields.",
        "operationId": "patch_api_admin_categories_id_status",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [
          {
            "name": "id",
            "in": "path",
            "required": true,
            "schema": {
              "type": "string"
            }
          }
        ],
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {
                "$ref": "#/components/schemas/CategoryStatusRequest"
              },
              "examples": {
                "default": {
                  "summary": "CategoryStatusRequest example",
                  "value": {
                    "active": false
                  }
                }
              }
            }
          }
        },
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {
                        "_id": "66b4f5a2a44d2c0012a9c102",
                        "name": "Business Books",
                        "slug": "business-books",
                        "active": true,
                        "featured": true,
                        "bookCount": 12
                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {
                        "_id": "66b4f5a2a44d2c0012a9c102",
                        "name": "Business Books",
                        "slug": "business-books",
                        "active": true,
                        "featured": true,
                        "bookCount": 12
                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "409": {
            "$ref": "#/components/responses/Conflict"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/admin/author-access/plans": {
      "get": {
        "tags": [
          "Admin Author Access"
        ],
        "summary": "List author access plans",
        "description": "List author access plans. Controller: adminAuthorAccessController.listPlans. Authentication: Admin. API routes are rate limited and return standard error envelopes.",
        "operationId": "get_api_admin_author_access_plans",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [],
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      },
      "post": {
        "tags": [
          "Admin Author Access"
        ],
        "summary": "Create author access plan",
        "description": "Create author access plan. Controller: adminAuthorAccessController.createPlan. Authentication: Admin. API routes are rate limited and return standard error envelopes.",
        "operationId": "post_api_admin_author_access_plans",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [],
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {
                "$ref": "#/components/schemas/AuthorAccessPlanRequest"
              },
              "examples": {
                "default": {
                  "summary": "AuthorAccessPlanRequest example",
                  "value": {
                    "name": "Author Dashboard Access",
                    "description": "One-time author dashboard operational access plan",
                    "amount": 4999,
                    "currency": "INR",
                    "status": "ACTIVE"
                  }
                }
              }
            }
          }
        },
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/admin/author-access/plans/{id}": {
      "put": {
        "tags": [
          "Admin Author Access"
        ],
        "summary": "Update author access plan",
        "description": "Update author access plan. Controller: adminAuthorAccessController.updatePlan. Authentication: Admin. API routes are rate limited and return standard error envelopes.",
        "operationId": "put_api_admin_author_access_plans_id",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [
          {
            "name": "id",
            "in": "path",
            "required": true,
            "schema": {
              "type": "string"
            }
          }
        ],
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {
                "$ref": "#/components/schemas/AuthorAccessPlanRequest"
              },
              "examples": {
                "default": {
                  "summary": "AuthorAccessPlanRequest example",
                  "value": {
                    "name": "Author Dashboard Access",
                    "description": "One-time author dashboard operational access plan",
                    "amount": 4999,
                    "currency": "INR",
                    "status": "ACTIVE"
                  }
                }
              }
            }
          }
        },
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/admin/author-access/plans/{id}/activate": {
      "post": {
        "tags": [
          "Admin Author Access"
        ],
        "summary": "Activate author access plan",
        "description": "Activate author access plan. Controller: adminAuthorAccessController.activatePlan. Authentication: Admin. API routes are rate limited and return standard error envelopes.",
        "operationId": "post_api_admin_author_access_plans_id_activate",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [
          {
            "name": "id",
            "in": "path",
            "required": true,
            "schema": {
              "type": "string"
            }
          }
        ],
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/admin/author-access/plans/{id}/archive": {
      "post": {
        "tags": [
          "Admin Author Access"
        ],
        "summary": "Archive author access plan",
        "description": "Archive author access plan. Controller: adminAuthorAccessController.archivePlan. Authentication: Admin. API routes are rate limited and return standard error envelopes.",
        "operationId": "post_api_admin_author_access_plans_id_archive",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [
          {
            "name": "id",
            "in": "path",
            "required": true,
            "schema": {
              "type": "string"
            }
          }
        ],
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/admin/author-access/purchases": {
      "get": {
        "tags": [
          "Admin Author Access"
        ],
        "summary": "List author access purchases",
        "description": "List author access purchases. Controller: adminAuthorAccessController.listPurchases. Authentication: Admin. API routes are rate limited and return standard error envelopes.",
        "operationId": "get_api_admin_author_access_purchases",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [
          {
            "name": "status",
            "in": "query",
            "required": false,
            "schema": {
              "type": "string"
            }
          },
          {
            "name": "userId",
            "in": "query",
            "required": false,
            "schema": {
              "type": "string"
            }
          },
          {
            "name": "page",
            "in": "query",
            "required": false,
            "schema": {
              "type": "integer",
              "minimum": 1,
              "default": 1
            }
          },
          {
            "name": "limit",
            "in": "query",
            "required": false,
            "schema": {
              "type": "integer",
              "minimum": 1,
              "maximum": 100,
              "default": 10
            }
          }
        ],
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/admin/author-access/entitlements": {
      "get": {
        "tags": [
          "Admin Author Access"
        ],
        "summary": "List author entitlements",
        "description": "List author entitlements. Controller: adminAuthorAccessController.listEntitlements. Authentication: Admin. API routes are rate limited and return standard error envelopes.",
        "operationId": "get_api_admin_author_access_entitlements",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [
          {
            "name": "status",
            "in": "query",
            "required": false,
            "schema": {
              "type": "string"
            }
          },
          {
            "name": "userId",
            "in": "query",
            "required": false,
            "schema": {
              "type": "string"
            }
          },
          {
            "name": "page",
            "in": "query",
            "required": false,
            "schema": {
              "type": "integer",
              "minimum": 1,
              "default": 1
            }
          },
          {
            "name": "limit",
            "in": "query",
            "required": false,
            "schema": {
              "type": "integer",
              "minimum": 1,
              "maximum": 100,
              "default": 10
            }
          }
        ],
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/admin/author-access/entitlements/grant": {
      "post": {
        "tags": [
          "Admin Author Access"
        ],
        "summary": "Admin manual grant author dashboard access",
        "description": "Admin manual grant author dashboard access. Controller: adminAuthorAccessController.grantEntitlement. Authentication: Admin. API routes are rate limited and return standard error envelopes.",
        "operationId": "post_api_admin_author_access_entitlements_grant",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [],
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {
                "$ref": "#/components/schemas/AuthorAccessGrantRequest"
              },
              "examples": {
                "default": {
                  "summary": "AuthorAccessGrantRequest example",
                  "value": {
                    "userId": "66b4f5a2a44d2c0012a9c105",
                    "reason": "Manual access approved by operations."
                  }
                }
              }
            }
          }
        },
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/admin/author-access/entitlements/{userId}/revoke": {
      "post": {
        "tags": [
          "Admin Author Access"
        ],
        "summary": "Admin revoke author dashboard access",
        "description": "Admin revoke author dashboard access. Controller: adminAuthorAccessController.revokeEntitlement. Authentication: Admin. API routes are rate limited and return standard error envelopes.",
        "operationId": "post_api_admin_author_access_entitlements_userId_revoke",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [
          {
            "name": "userId",
            "in": "path",
            "required": true,
            "schema": {
              "type": "string"
            }
          }
        ],
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {
                "$ref": "#/components/schemas/AuthorAccessReasonRequest"
              },
              "examples": {
                "default": {
                  "summary": "AuthorAccessReasonRequest example",
                  "value": {
                    "reason": "Administrative entitlement update."
                  }
                }
              }
            }
          }
        },
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/admin/author-access/entitlements/{userId}/restore": {
      "post": {
        "tags": [
          "Admin Author Access"
        ],
        "summary": "Admin restore author dashboard access",
        "description": "Admin restore author dashboard access. Controller: adminAuthorAccessController.restoreEntitlement. Authentication: Admin. API routes are rate limited and return standard error envelopes.",
        "operationId": "post_api_admin_author_access_entitlements_userId_restore",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [
          {
            "name": "userId",
            "in": "path",
            "required": true,
            "schema": {
              "type": "string"
            }
          }
        ],
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {
                "$ref": "#/components/schemas/AuthorAccessReasonRequest"
              },
              "examples": {
                "default": {
                  "summary": "AuthorAccessReasonRequest example",
                  "value": {
                    "reason": "Administrative entitlement update."
                  }
                }
              }
            }
          }
        },
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/admin/authors/{authorId}/dashboard": {
      "get": {
        "tags": [
          "Admin Author Access"
        ],
        "summary": "Admin inspect author dashboard metrics",
        "description": "Admin inspect author dashboard metrics. Controller: adminController.getAdminAuthorDashboard. Authentication: Admin. API routes are rate limited and return standard error envelopes.",
        "operationId": "get_api_admin_authors_authorId_dashboard",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [
          {
            "name": "authorId",
            "in": "path",
            "required": true,
            "schema": {
              "type": "string"
            }
          }
        ],
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/admin/authors/{authorId}/royalties": {
      "get": {
        "tags": [
          "Admin Author Access"
        ],
        "summary": "Admin inspect author royalty history",
        "description": "Admin inspect author royalty history. Controller: adminController.getAdminAuthorRoyalties. Authentication: Admin. API routes are rate limited and return standard error envelopes.",
        "operationId": "get_api_admin_authors_authorId_royalties",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [
          {
            "name": "authorId",
            "in": "path",
            "required": true,
            "schema": {
              "type": "string"
            }
          },
          {
            "name": "page",
            "in": "query",
            "required": false,
            "schema": {
              "type": "integer",
              "minimum": 1,
              "default": 1
            }
          },
          {
            "name": "limit",
            "in": "query",
            "required": false,
            "schema": {
              "type": "integer",
              "minimum": 1,
              "maximum": 100,
              "default": 10
            }
          },
          {
            "name": "bookId",
            "in": "query",
            "required": false,
            "schema": {
              "type": "string"
            }
          },
          {
            "name": "from",
            "in": "query",
            "required": false,
            "schema": {
              "type": "string",
              "format": "date-time"
            }
          },
          {
            "name": "to",
            "in": "query",
            "required": false,
            "schema": {
              "type": "string",
              "format": "date-time"
            }
          }
        ],
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/admin/operations/dashboard": {
      "get": {
        "tags": [
          "Admin Operations"
        ],
        "summary": "Operations dashboard",
        "description": "Operations dashboard. Controller: adminOperationsController.dashboardSummary. Authentication: Admin. API routes are rate limited and return standard error envelopes.",
        "operationId": "get_api_admin_operations_dashboard",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [],
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {
                        "items": [],
                        "pagination": {
                          "total": 0,
                          "page": 1,
                          "limit": 20,
                          "pages": 0
                        }
                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {
                        "items": [],
                        "pagination": {
                          "total": 0,
                          "page": 1,
                          "limit": 20,
                          "pages": 0
                        }
                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/admin/operations/search": {
      "get": {
        "tags": [
          "Admin Operations"
        ],
        "summary": "Global operations search",
        "description": "Global operations search. Controller: adminOperationsController.globalSearch. Authentication: Admin. API routes are rate limited and return standard error envelopes.",
        "operationId": "get_api_admin_operations_search",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [
          {
            "name": "q",
            "in": "query",
            "required": false,
            "schema": {
              "type": "string"
            }
          },
          {
            "name": "type",
            "in": "query",
            "required": false,
            "schema": {
              "type": "string"
            }
          },
          {
            "name": "page",
            "in": "query",
            "required": false,
            "schema": {
              "type": "integer",
              "minimum": 1,
              "default": 1
            }
          },
          {
            "name": "limit",
            "in": "query",
            "required": false,
            "schema": {
              "type": "integer",
              "minimum": 1,
              "maximum": 100,
              "default": 10
            }
          }
        ],
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {
                        "items": [],
                        "pagination": {
                          "total": 0,
                          "page": 1,
                          "limit": 20,
                          "pages": 0
                        }
                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {
                        "items": [],
                        "pagination": {
                          "total": 0,
                          "page": 1,
                          "limit": 20,
                          "pages": 0
                        }
                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/admin/operations/payments": {
      "get": {
        "tags": [
          "Admin Operations"
        ],
        "summary": "List payments",
        "description": "List payments. Controller: adminOperationsController.listPayments. Authentication: Admin. API routes are rate limited and return standard error envelopes.",
        "operationId": "get_api_admin_operations_payments",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [
          {
            "name": "status",
            "in": "query",
            "required": false,
            "schema": {
              "type": "string"
            }
          },
          {
            "name": "page",
            "in": "query",
            "required": false,
            "schema": {
              "type": "integer",
              "minimum": 1,
              "default": 1
            }
          },
          {
            "name": "limit",
            "in": "query",
            "required": false,
            "schema": {
              "type": "integer",
              "minimum": 1,
              "maximum": 100,
              "default": 10
            }
          },
          {
            "name": "from",
            "in": "query",
            "required": false,
            "schema": {
              "type": "string",
              "format": "date-time"
            }
          },
          {
            "name": "to",
            "in": "query",
            "required": false,
            "schema": {
              "type": "string",
              "format": "date-time"
            }
          }
        ],
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {
                        "items": [],
                        "pagination": {
                          "total": 0,
                          "page": 1,
                          "limit": 20,
                          "pages": 0
                        }
                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {
                        "items": [],
                        "pagination": {
                          "total": 0,
                          "page": 1,
                          "limit": 20,
                          "pages": 0
                        }
                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "409": {
            "$ref": "#/components/responses/Conflict"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/admin/operations/payments/{id}": {
      "get": {
        "tags": [
          "Admin Operations"
        ],
        "summary": "Payment detail",
        "description": "Payment detail. Controller: adminOperationsController.getPaymentDetail. Authentication: Admin. API routes are rate limited and return standard error envelopes.",
        "operationId": "get_api_admin_operations_payments_id",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [
          {
            "name": "id",
            "in": "path",
            "required": true,
            "schema": {
              "type": "string"
            }
          }
        ],
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {
                        "items": [],
                        "pagination": {
                          "total": 0,
                          "page": 1,
                          "limit": 20,
                          "pages": 0
                        }
                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {
                        "items": [],
                        "pagination": {
                          "total": 0,
                          "page": 1,
                          "limit": 20,
                          "pages": 0
                        }
                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "409": {
            "$ref": "#/components/responses/Conflict"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/admin/operations/payments/{id}/approve": {
      "post": {
        "tags": [
          "Admin Operations"
        ],
        "summary": "Approve payment",
        "description": "Approve payment. Controller: adminOperationsController.approvePayment. Authentication: Admin. API routes are rate limited and return standard error envelopes.",
        "operationId": "post_api_admin_operations_payments_id_approve",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [
          {
            "name": "id",
            "in": "path",
            "required": true,
            "schema": {
              "type": "string"
            }
          }
        ],
        "requestBody": {
          "required": false,
          "content": {
            "application/json": {
              "schema": {
                "$ref": "#/components/schemas/PaymentActionRequest"
              },
              "examples": {
                "default": {
                  "summary": "PaymentActionRequest example",
                  "value": {
                    "reason": "Approved after manual verification",
                    "metadata": {
                      "source": "admin-dashboard"
                    }
                  }
                }
              }
            }
          }
        },
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {
                        "items": [],
                        "pagination": {
                          "total": 0,
                          "page": 1,
                          "limit": 20,
                          "pages": 0
                        }
                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {
                        "items": [],
                        "pagination": {
                          "total": 0,
                          "page": 1,
                          "limit": 20,
                          "pages": 0
                        }
                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "409": {
            "$ref": "#/components/responses/Conflict"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/admin/operations/payments/{id}/reject": {
      "post": {
        "tags": [
          "Admin Operations"
        ],
        "summary": "Reject payment",
        "description": "Reject payment. Controller: adminOperationsController.rejectPayment. Authentication: Admin. API routes are rate limited and return standard error envelopes.",
        "operationId": "post_api_admin_operations_payments_id_reject",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [
          {
            "name": "id",
            "in": "path",
            "required": true,
            "schema": {
              "type": "string"
            }
          }
        ],
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {
                "$ref": "#/components/schemas/RejectPaymentRequest"
              },
              "examples": {
                "default": {
                  "summary": "RejectPaymentRequest example",
                  "value": {
                    "reason": "UTR could not be verified"
                  }
                }
              }
            }
          }
        },
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {
                        "items": [],
                        "pagination": {
                          "total": 0,
                          "page": 1,
                          "limit": 20,
                          "pages": 0
                        }
                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {
                        "items": [],
                        "pagination": {
                          "total": 0,
                          "page": 1,
                          "limit": 20,
                          "pages": 0
                        }
                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "409": {
            "$ref": "#/components/responses/Conflict"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/admin/operations/payments/{id}/cancel": {
      "post": {
        "tags": [
          "Admin Operations"
        ],
        "summary": "Cancel payment intent",
        "description": "Cancel payment intent. Controller: adminOperationsController.cancelPaymentIntent. Authentication: Admin. API routes are rate limited and return standard error envelopes.",
        "operationId": "post_api_admin_operations_payments_id_cancel",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [
          {
            "name": "id",
            "in": "path",
            "required": true,
            "schema": {
              "type": "string"
            }
          }
        ],
        "requestBody": {
          "required": false,
          "content": {
            "application/json": {
              "schema": {
                "$ref": "#/components/schemas/PaymentActionRequest"
              },
              "examples": {
                "default": {
                  "summary": "PaymentActionRequest example",
                  "value": {
                    "reason": "Approved after manual verification",
                    "metadata": {
                      "source": "admin-dashboard"
                    }
                  }
                }
              }
            }
          }
        },
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {
                        "items": [],
                        "pagination": {
                          "total": 0,
                          "page": 1,
                          "limit": 20,
                          "pages": 0
                        }
                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {
                        "items": [],
                        "pagination": {
                          "total": 0,
                          "page": 1,
                          "limit": 20,
                          "pages": 0
                        }
                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "409": {
            "$ref": "#/components/responses/Conflict"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/admin/operations/payments/{id}/expire": {
      "post": {
        "tags": [
          "Admin Operations"
        ],
        "summary": "Expire payment intent",
        "description": "Expire payment intent. Controller: adminOperationsController.expirePayment. Authentication: Admin. API routes are rate limited and return standard error envelopes.",
        "operationId": "post_api_admin_operations_payments_id_expire",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [
          {
            "name": "id",
            "in": "path",
            "required": true,
            "schema": {
              "type": "string"
            }
          }
        ],
        "requestBody": {
          "required": false,
          "content": {
            "application/json": {
              "schema": {
                "$ref": "#/components/schemas/PaymentActionRequest"
              },
              "examples": {
                "default": {
                  "summary": "PaymentActionRequest example",
                  "value": {
                    "reason": "Approved after manual verification",
                    "metadata": {
                      "source": "admin-dashboard"
                    }
                  }
                }
              }
            }
          }
        },
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {
                        "items": [],
                        "pagination": {
                          "total": 0,
                          "page": 1,
                          "limit": 20,
                          "pages": 0
                        }
                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {
                        "items": [],
                        "pagination": {
                          "total": 0,
                          "page": 1,
                          "limit": 20,
                          "pages": 0
                        }
                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "409": {
            "$ref": "#/components/responses/Conflict"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/admin/operations/payments/{id}/retry-verification": {
      "post": {
        "tags": [
          "Admin Operations"
        ],
        "summary": "Retry payment verification",
        "description": "Retry payment verification. Controller: adminOperationsController.retryVerification. Authentication: Admin. API routes are rate limited and return standard error envelopes.",
        "operationId": "post_api_admin_operations_payments_id_retry_verification",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [
          {
            "name": "id",
            "in": "path",
            "required": true,
            "schema": {
              "type": "string"
            }
          }
        ],
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {
                        "items": [],
                        "pagination": {
                          "total": 0,
                          "page": 1,
                          "limit": 20,
                          "pages": 0
                        }
                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {
                        "items": [],
                        "pagination": {
                          "total": 0,
                          "page": 1,
                          "limit": 20,
                          "pages": 0
                        }
                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "409": {
            "$ref": "#/components/responses/Conflict"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/admin/operations/payments/{id}/recreate-qr": {
      "post": {
        "tags": [
          "Admin Operations"
        ],
        "summary": "Recreate payment QR",
        "description": "Recreate payment QR. Controller: adminOperationsController.recreateQR. Authentication: Admin. API routes are rate limited and return standard error envelopes.",
        "operationId": "post_api_admin_operations_payments_id_recreate_qr",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [
          {
            "name": "id",
            "in": "path",
            "required": true,
            "schema": {
              "type": "string"
            }
          }
        ],
        "requestBody": {
          "required": false,
          "content": {
            "application/json": {
              "schema": {
                "$ref": "#/components/schemas/QRRegenerateRequest"
              },
              "examples": {
                "default": {
                  "summary": "QRRegenerateRequest example",
                  "value": {
                    "force": true,
                    "reason": "Customer requested a fresh QR"
                  }
                }
              }
            }
          }
        },
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {
                        "items": [],
                        "pagination": {
                          "total": 0,
                          "page": 1,
                          "limit": 20,
                          "pages": 0
                        }
                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {
                        "items": [],
                        "pagination": {
                          "total": 0,
                          "page": 1,
                          "limit": 20,
                          "pages": 0
                        }
                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "409": {
            "$ref": "#/components/responses/Conflict"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/admin/operations/inventory/reservations": {
      "get": {
        "tags": [
          "Admin Operations"
        ],
        "summary": "List inventory reservations",
        "description": "List inventory reservations. Controller: adminOperationsController.listReservations. Authentication: Admin. API routes are rate limited and return standard error envelopes.",
        "operationId": "get_api_admin_operations_inventory_reservations",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [
          {
            "name": "status",
            "in": "query",
            "required": false,
            "schema": {
              "type": "string"
            }
          },
          {
            "name": "order",
            "in": "query",
            "required": false,
            "schema": {
              "type": "string"
            }
          },
          {
            "name": "payment",
            "in": "query",
            "required": false,
            "schema": {
              "type": "string"
            }
          },
          {
            "name": "book",
            "in": "query",
            "required": false,
            "schema": {
              "type": "string"
            }
          },
          {
            "name": "page",
            "in": "query",
            "required": false,
            "schema": {
              "type": "integer",
              "minimum": 1,
              "default": 1
            }
          },
          {
            "name": "limit",
            "in": "query",
            "required": false,
            "schema": {
              "type": "integer",
              "minimum": 1,
              "maximum": 100,
              "default": 10
            }
          },
          {
            "name": "from",
            "in": "query",
            "required": false,
            "schema": {
              "type": "string",
              "format": "date-time"
            }
          },
          {
            "name": "to",
            "in": "query",
            "required": false,
            "schema": {
              "type": "string",
              "format": "date-time"
            }
          }
        ],
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {
                        "items": [],
                        "pagination": {
                          "total": 0,
                          "page": 1,
                          "limit": 20,
                          "pages": 0
                        }
                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {
                        "items": [],
                        "pagination": {
                          "total": 0,
                          "page": 1,
                          "limit": 20,
                          "pages": 0
                        }
                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/admin/operations/inventory/low-stock": {
      "get": {
        "tags": [
          "Admin Operations"
        ],
        "summary": "List low stock books",
        "description": "List low stock books. Controller: adminOperationsController.listLowStock. Authentication: Admin. API routes are rate limited and return standard error envelopes.",
        "operationId": "get_api_admin_operations_inventory_low_stock",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [
          {
            "name": "threshold",
            "in": "query",
            "required": false,
            "schema": {
              "type": "integer",
              "minimum": 0
            }
          },
          {
            "name": "page",
            "in": "query",
            "required": false,
            "schema": {
              "type": "integer",
              "minimum": 1,
              "default": 1
            }
          },
          {
            "name": "limit",
            "in": "query",
            "required": false,
            "schema": {
              "type": "integer",
              "minimum": 1,
              "maximum": 100,
              "default": 10
            }
          },
          {
            "name": "category",
            "in": "query",
            "required": false,
            "schema": {
              "type": "string"
            }
          }
        ],
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {
                        "items": [],
                        "pagination": {
                          "total": 0,
                          "page": 1,
                          "limit": 20,
                          "pages": 0
                        }
                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {
                        "items": [],
                        "pagination": {
                          "total": 0,
                          "page": 1,
                          "limit": 20,
                          "pages": 0
                        }
                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/admin/operations/ledger/payments": {
      "get": {
        "tags": [
          "Admin Operations"
        ],
        "summary": "List payment ledger",
        "description": "List payment ledger. Controller: adminOperationsController.listPaymentLedger. Authentication: Admin. API routes are rate limited and return standard error envelopes.",
        "operationId": "get_api_admin_operations_ledger_payments",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [
          {
            "name": "paymentId",
            "in": "query",
            "required": false,
            "schema": {
              "type": "string"
            }
          },
          {
            "name": "orderId",
            "in": "query",
            "required": false,
            "schema": {
              "type": "string"
            }
          },
          {
            "name": "userId",
            "in": "query",
            "required": false,
            "schema": {
              "type": "string"
            }
          },
          {
            "name": "eventType",
            "in": "query",
            "required": false,
            "schema": {
              "type": "string"
            }
          },
          {
            "name": "page",
            "in": "query",
            "required": false,
            "schema": {
              "type": "integer",
              "minimum": 1,
              "default": 1
            }
          },
          {
            "name": "limit",
            "in": "query",
            "required": false,
            "schema": {
              "type": "integer",
              "minimum": 1,
              "maximum": 100,
              "default": 10
            }
          },
          {
            "name": "from",
            "in": "query",
            "required": false,
            "schema": {
              "type": "string",
              "format": "date-time"
            }
          },
          {
            "name": "to",
            "in": "query",
            "required": false,
            "schema": {
              "type": "string",
              "format": "date-time"
            }
          }
        ],
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {
                        "items": [],
                        "pagination": {
                          "total": 0,
                          "page": 1,
                          "limit": 20,
                          "pages": 0
                        }
                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {
                        "items": [],
                        "pagination": {
                          "total": 0,
                          "page": 1,
                          "limit": 20,
                          "pages": 0
                        }
                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/admin/operations/ledger/inventory": {
      "get": {
        "tags": [
          "Admin Operations"
        ],
        "summary": "List inventory ledger",
        "description": "List inventory ledger. Controller: adminOperationsController.listInventoryLedger. Authentication: Admin. API routes are rate limited and return standard error envelopes.",
        "operationId": "get_api_admin_operations_ledger_inventory",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [
          {
            "name": "reservation",
            "in": "query",
            "required": false,
            "schema": {
              "type": "string"
            }
          },
          {
            "name": "order",
            "in": "query",
            "required": false,
            "schema": {
              "type": "string"
            }
          },
          {
            "name": "payment",
            "in": "query",
            "required": false,
            "schema": {
              "type": "string"
            }
          },
          {
            "name": "book",
            "in": "query",
            "required": false,
            "schema": {
              "type": "string"
            }
          },
          {
            "name": "eventType",
            "in": "query",
            "required": false,
            "schema": {
              "type": "string"
            }
          },
          {
            "name": "page",
            "in": "query",
            "required": false,
            "schema": {
              "type": "integer",
              "minimum": 1,
              "default": 1
            }
          },
          {
            "name": "limit",
            "in": "query",
            "required": false,
            "schema": {
              "type": "integer",
              "minimum": 1,
              "maximum": 100,
              "default": 10
            }
          },
          {
            "name": "from",
            "in": "query",
            "required": false,
            "schema": {
              "type": "string",
              "format": "date-time"
            }
          },
          {
            "name": "to",
            "in": "query",
            "required": false,
            "schema": {
              "type": "string",
              "format": "date-time"
            }
          }
        ],
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {
                        "items": [],
                        "pagination": {
                          "total": 0,
                          "page": 1,
                          "limit": 20,
                          "pages": 0
                        }
                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {
                        "items": [],
                        "pagination": {
                          "total": 0,
                          "page": 1,
                          "limit": 20,
                          "pages": 0
                        }
                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/admin/operations/ledger/timeline": {
      "get": {
        "tags": [
          "Admin Operations"
        ],
        "summary": "Combined ledger timeline",
        "description": "Combined ledger timeline. Controller: adminOperationsController.combinedTimeline. Authentication: Admin. API routes are rate limited and return standard error envelopes.",
        "operationId": "get_api_admin_operations_ledger_timeline",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [
          {
            "name": "orderId",
            "in": "query",
            "required": false,
            "schema": {
              "type": "string"
            }
          },
          {
            "name": "paymentId",
            "in": "query",
            "required": false,
            "schema": {
              "type": "string"
            }
          },
          {
            "name": "page",
            "in": "query",
            "required": false,
            "schema": {
              "type": "integer",
              "minimum": 1,
              "default": 1
            }
          },
          {
            "name": "limit",
            "in": "query",
            "required": false,
            "schema": {
              "type": "integer",
              "minimum": 1,
              "maximum": 100,
              "default": 10
            }
          },
          {
            "name": "from",
            "in": "query",
            "required": false,
            "schema": {
              "type": "string",
              "format": "date-time"
            }
          },
          {
            "name": "to",
            "in": "query",
            "required": false,
            "schema": {
              "type": "string",
              "format": "date-time"
            }
          }
        ],
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {
                        "items": [],
                        "pagination": {
                          "total": 0,
                          "page": 1,
                          "limit": 20,
                          "pages": 0
                        }
                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {
                        "items": [],
                        "pagination": {
                          "total": 0,
                          "page": 1,
                          "limit": 20,
                          "pages": 0
                        }
                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/admin/invoices/search": {
      "get": {
        "tags": [
          "Admin Invoices"
        ],
        "summary": "Search invoices",
        "description": "Search invoices. Controller: adminInvoiceController.searchInvoices. Authentication: Admin. API routes are rate limited and return standard error envelopes.",
        "operationId": "get_api_admin_invoices_search",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [
          {
            "name": "q",
            "in": "query",
            "required": false,
            "schema": {
              "type": "string"
            }
          },
          {
            "name": "search",
            "in": "query",
            "required": false,
            "schema": {
              "type": "string"
            }
          },
          {
            "name": "status",
            "in": "query",
            "required": false,
            "schema": {
              "type": "string"
            }
          },
          {
            "name": "customer",
            "in": "query",
            "required": false,
            "schema": {
              "type": "string"
            }
          },
          {
            "name": "order",
            "in": "query",
            "required": false,
            "schema": {
              "type": "string"
            }
          },
          {
            "name": "payment",
            "in": "query",
            "required": false,
            "schema": {
              "type": "string"
            }
          },
          {
            "name": "page",
            "in": "query",
            "required": false,
            "schema": {
              "type": "integer",
              "minimum": 1,
              "default": 1
            }
          },
          {
            "name": "limit",
            "in": "query",
            "required": false,
            "schema": {
              "type": "integer",
              "minimum": 1,
              "maximum": 100,
              "default": 10
            }
          },
          {
            "name": "from",
            "in": "query",
            "required": false,
            "schema": {
              "type": "string",
              "format": "date-time"
            }
          },
          {
            "name": "to",
            "in": "query",
            "required": false,
            "schema": {
              "type": "string",
              "format": "date-time"
            }
          }
        ],
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {
                        "invoiceNumber": "INV-202607-000001",
                        "status": "GENERATED",
                        "total": 998,
                        "currency": "INR"
                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {
                        "invoiceNumber": "INV-202607-000001",
                        "status": "GENERATED",
                        "total": 998,
                        "currency": "INR"
                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/admin/invoices": {
      "get": {
        "tags": [
          "Admin Invoices"
        ],
        "summary": "List invoices",
        "description": "List invoices. Controller: adminInvoiceController.listInvoices. Authentication: Admin. API routes are rate limited and return standard error envelopes.",
        "operationId": "get_api_admin_invoices",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [
          {
            "name": "status",
            "in": "query",
            "required": false,
            "schema": {
              "type": "string"
            }
          },
          {
            "name": "customer",
            "in": "query",
            "required": false,
            "schema": {
              "type": "string"
            }
          },
          {
            "name": "order",
            "in": "query",
            "required": false,
            "schema": {
              "type": "string"
            }
          },
          {
            "name": "payment",
            "in": "query",
            "required": false,
            "schema": {
              "type": "string"
            }
          },
          {
            "name": "page",
            "in": "query",
            "required": false,
            "schema": {
              "type": "integer",
              "minimum": 1,
              "default": 1
            }
          },
          {
            "name": "limit",
            "in": "query",
            "required": false,
            "schema": {
              "type": "integer",
              "minimum": 1,
              "maximum": 100,
              "default": 10
            }
          },
          {
            "name": "from",
            "in": "query",
            "required": false,
            "schema": {
              "type": "string",
              "format": "date-time"
            }
          },
          {
            "name": "to",
            "in": "query",
            "required": false,
            "schema": {
              "type": "string",
              "format": "date-time"
            }
          }
        ],
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {
                        "invoiceNumber": "INV-202607-000001",
                        "status": "GENERATED",
                        "total": 998,
                        "currency": "INR"
                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {
                        "invoiceNumber": "INV-202607-000001",
                        "status": "GENERATED",
                        "total": 998,
                        "currency": "INR"
                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/admin/invoices/{id}/download": {
      "get": {
        "tags": [
          "Admin Invoices"
        ],
        "summary": "Download invoice document",
        "description": "Download invoice document. Controller: adminInvoiceController.downloadInvoice. Authentication: Admin. API routes are rate limited and return standard error envelopes.",
        "operationId": "get_api_admin_invoices_id_download",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [
          {
            "name": "id",
            "in": "path",
            "required": true,
            "schema": {
              "type": "string"
            }
          }
        ],
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {
                        "invoiceNumber": "INV-202607-000001",
                        "status": "GENERATED",
                        "total": 998,
                        "currency": "INR"
                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {
                        "invoiceNumber": "INV-202607-000001",
                        "status": "GENERATED",
                        "total": 998,
                        "currency": "INR"
                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/admin/invoices/{id}": {
      "get": {
        "tags": [
          "Admin Invoices"
        ],
        "summary": "Get invoice",
        "description": "Get invoice. Controller: adminInvoiceController.getInvoice. Authentication: Admin. API routes are rate limited and return standard error envelopes.",
        "operationId": "get_api_admin_invoices_id",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [
          {
            "name": "id",
            "in": "path",
            "required": true,
            "schema": {
              "type": "string"
            }
          }
        ],
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {
                        "invoiceNumber": "INV-202607-000001",
                        "status": "GENERATED",
                        "total": 998,
                        "currency": "INR"
                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {
                        "invoiceNumber": "INV-202607-000001",
                        "status": "GENERATED",
                        "total": 998,
                        "currency": "INR"
                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/admin/notifications/search": {
      "get": {
        "tags": [
          "Admin Notifications"
        ],
        "summary": "Search notifications",
        "description": "Search notifications. Controller: adminNotificationController.searchNotifications. Authentication: Admin. API routes are rate limited and return standard error envelopes.",
        "operationId": "get_api_admin_notifications_search",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [
          {
            "name": "q",
            "in": "query",
            "required": false,
            "schema": {
              "type": "string"
            }
          },
          {
            "name": "search",
            "in": "query",
            "required": false,
            "schema": {
              "type": "string"
            }
          },
          {
            "name": "status",
            "in": "query",
            "required": false,
            "schema": {
              "type": "string"
            }
          },
          {
            "name": "channel",
            "in": "query",
            "required": false,
            "schema": {
              "type": "string"
            }
          },
          {
            "name": "eventType",
            "in": "query",
            "required": false,
            "schema": {
              "type": "string"
            }
          },
          {
            "name": "user",
            "in": "query",
            "required": false,
            "schema": {
              "type": "string"
            }
          },
          {
            "name": "page",
            "in": "query",
            "required": false,
            "schema": {
              "type": "integer",
              "minimum": 1,
              "default": 1
            }
          },
          {
            "name": "limit",
            "in": "query",
            "required": false,
            "schema": {
              "type": "integer",
              "minimum": 1,
              "maximum": 100,
              "default": 10
            }
          },
          {
            "name": "from",
            "in": "query",
            "required": false,
            "schema": {
              "type": "string",
              "format": "date-time"
            }
          },
          {
            "name": "to",
            "in": "query",
            "required": false,
            "schema": {
              "type": "string",
              "format": "date-time"
            }
          }
        ],
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {
                        "items": [],
                        "pagination": {
                          "total": 0,
                          "page": 1,
                          "limit": 20,
                          "pages": 0
                        }
                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {
                        "items": [],
                        "pagination": {
                          "total": 0,
                          "page": 1,
                          "limit": 20,
                          "pages": 0
                        }
                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/admin/notifications": {
      "get": {
        "tags": [
          "Admin Notifications"
        ],
        "summary": "List notifications",
        "description": "List notifications. Controller: adminNotificationController.listNotifications. Authentication: Admin. API routes are rate limited and return standard error envelopes.",
        "operationId": "get_api_admin_notifications",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [
          {
            "name": "status",
            "in": "query",
            "required": false,
            "schema": {
              "type": "string"
            }
          },
          {
            "name": "channel",
            "in": "query",
            "required": false,
            "schema": {
              "type": "string"
            }
          },
          {
            "name": "eventType",
            "in": "query",
            "required": false,
            "schema": {
              "type": "string"
            }
          },
          {
            "name": "user",
            "in": "query",
            "required": false,
            "schema": {
              "type": "string"
            }
          },
          {
            "name": "page",
            "in": "query",
            "required": false,
            "schema": {
              "type": "integer",
              "minimum": 1,
              "default": 1
            }
          },
          {
            "name": "limit",
            "in": "query",
            "required": false,
            "schema": {
              "type": "integer",
              "minimum": 1,
              "maximum": 100,
              "default": 10
            }
          },
          {
            "name": "from",
            "in": "query",
            "required": false,
            "schema": {
              "type": "string",
              "format": "date-time"
            }
          },
          {
            "name": "to",
            "in": "query",
            "required": false,
            "schema": {
              "type": "string",
              "format": "date-time"
            }
          }
        ],
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {
                        "items": [],
                        "pagination": {
                          "total": 0,
                          "page": 1,
                          "limit": 20,
                          "pages": 0
                        }
                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {
                        "items": [],
                        "pagination": {
                          "total": 0,
                          "page": 1,
                          "limit": 20,
                          "pages": 0
                        }
                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/admin/notifications/{id}": {
      "get": {
        "tags": [
          "Admin Notifications"
        ],
        "summary": "Get notification",
        "description": "Get notification. Controller: adminNotificationController.getNotification. Authentication: Admin. API routes are rate limited and return standard error envelopes.",
        "operationId": "get_api_admin_notifications_id",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [
          {
            "name": "id",
            "in": "path",
            "required": true,
            "schema": {
              "type": "string"
            }
          }
        ],
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {
                        "items": [],
                        "pagination": {
                          "total": 0,
                          "page": 1,
                          "limit": 20,
                          "pages": 0
                        }
                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {
                        "items": [],
                        "pagination": {
                          "total": 0,
                          "page": 1,
                          "limit": 20,
                          "pages": 0
                        }
                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/admin/notifications/{id}/retry": {
      "post": {
        "tags": [
          "Admin Notifications"
        ],
        "summary": "Retry failed notification",
        "description": "Retry failed notification. Controller: adminNotificationController.retryNotification. Authentication: Admin. API routes are rate limited and return standard error envelopes.",
        "operationId": "post_api_admin_notifications_id_retry",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [
          {
            "name": "id",
            "in": "path",
            "required": true,
            "schema": {
              "type": "string"
            }
          }
        ],
        "requestBody": {
          "required": false,
          "content": {
            "application/json": {
              "schema": {
                "$ref": "#/components/schemas/NotificationRetryRequest"
              },
              "examples": {
                "default": {
                  "summary": "NotificationRetryRequest example",
                  "value": {
                    "reason": "Retry after provider recovery",
                    "force": false
                  }
                }
              }
            }
          }
        },
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {
                        "items": [],
                        "pagination": {
                          "total": 0,
                          "page": 1,
                          "limit": 20,
                          "pages": 0
                        }
                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {
                        "items": [],
                        "pagination": {
                          "total": 0,
                          "page": 1,
                          "limit": 20,
                          "pages": 0
                        }
                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/admin/shipments/search": {
      "get": {
        "tags": [
          "Admin Shipments"
        ],
        "summary": "Search shipments",
        "description": "Search shipments. Controller: adminShipmentController.searchShipments. Authentication: Admin. API routes are rate limited and return standard error envelopes.",
        "operationId": "get_api_admin_shipments_search",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [
          {
            "name": "q",
            "in": "query",
            "required": false,
            "schema": {
              "type": "string"
            }
          },
          {
            "name": "search",
            "in": "query",
            "required": false,
            "schema": {
              "type": "string"
            }
          },
          {
            "name": "status",
            "in": "query",
            "required": false,
            "schema": {
              "type": "string"
            }
          },
          {
            "name": "customer",
            "in": "query",
            "required": false,
            "schema": {
              "type": "string"
            }
          },
          {
            "name": "order",
            "in": "query",
            "required": false,
            "schema": {
              "type": "string"
            }
          },
          {
            "name": "payment",
            "in": "query",
            "required": false,
            "schema": {
              "type": "string"
            }
          },
          {
            "name": "invoice",
            "in": "query",
            "required": false,
            "schema": {
              "type": "string"
            }
          },
          {
            "name": "page",
            "in": "query",
            "required": false,
            "schema": {
              "type": "integer",
              "minimum": 1,
              "default": 1
            }
          },
          {
            "name": "limit",
            "in": "query",
            "required": false,
            "schema": {
              "type": "integer",
              "minimum": 1,
              "maximum": 100,
              "default": 10
            }
          },
          {
            "name": "from",
            "in": "query",
            "required": false,
            "schema": {
              "type": "string",
              "format": "date-time"
            }
          },
          {
            "name": "to",
            "in": "query",
            "required": false,
            "schema": {
              "type": "string",
              "format": "date-time"
            }
          }
        ],
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {
                        "shipmentNumber": "SHP-202607-000001",
                        "status": "CREATED"
                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {
                        "shipmentNumber": "SHP-202607-000001",
                        "status": "CREATED"
                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/admin/shipments": {
      "get": {
        "tags": [
          "Admin Shipments"
        ],
        "summary": "List shipments",
        "description": "List shipments. Controller: adminShipmentController.listShipments. Authentication: Admin. API routes are rate limited and return standard error envelopes.",
        "operationId": "get_api_admin_shipments",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [
          {
            "name": "status",
            "in": "query",
            "required": false,
            "schema": {
              "type": "string"
            }
          },
          {
            "name": "customer",
            "in": "query",
            "required": false,
            "schema": {
              "type": "string"
            }
          },
          {
            "name": "order",
            "in": "query",
            "required": false,
            "schema": {
              "type": "string"
            }
          },
          {
            "name": "payment",
            "in": "query",
            "required": false,
            "schema": {
              "type": "string"
            }
          },
          {
            "name": "invoice",
            "in": "query",
            "required": false,
            "schema": {
              "type": "string"
            }
          },
          {
            "name": "page",
            "in": "query",
            "required": false,
            "schema": {
              "type": "integer",
              "minimum": 1,
              "default": 1
            }
          },
          {
            "name": "limit",
            "in": "query",
            "required": false,
            "schema": {
              "type": "integer",
              "minimum": 1,
              "maximum": 100,
              "default": 10
            }
          },
          {
            "name": "from",
            "in": "query",
            "required": false,
            "schema": {
              "type": "string",
              "format": "date-time"
            }
          },
          {
            "name": "to",
            "in": "query",
            "required": false,
            "schema": {
              "type": "string",
              "format": "date-time"
            }
          }
        ],
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {
                        "shipmentNumber": "SHP-202607-000001",
                        "status": "CREATED"
                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {
                        "shipmentNumber": "SHP-202607-000001",
                        "status": "CREATED"
                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/admin/shipments/{id}/tracking": {
      "get": {
        "tags": [
          "Admin Shipments"
        ],
        "summary": "Get shipment tracking",
        "description": "Get shipment tracking. Controller: adminShipmentController.getTracking. Authentication: Admin. API routes are rate limited and return standard error envelopes.",
        "operationId": "get_api_admin_shipments_id_tracking",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [
          {
            "name": "id",
            "in": "path",
            "required": true,
            "schema": {
              "type": "string"
            }
          }
        ],
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {
                        "shipmentNumber": "SHP-202607-000001",
                        "status": "CREATED"
                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {
                        "shipmentNumber": "SHP-202607-000001",
                        "status": "CREATED"
                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/admin/shipments/{id}": {
      "get": {
        "tags": [
          "Admin Shipments"
        ],
        "summary": "Get shipment",
        "description": "Get shipment. Controller: adminShipmentController.getShipment. Authentication: Admin. API routes are rate limited and return standard error envelopes.",
        "operationId": "get_api_admin_shipments_id",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [
          {
            "name": "id",
            "in": "path",
            "required": true,
            "schema": {
              "type": "string"
            }
          }
        ],
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {
                        "shipmentNumber": "SHP-202607-000001",
                        "status": "CREATED"
                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {
                        "shipmentNumber": "SHP-202607-000001",
                        "status": "CREATED"
                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/admin/shipments/{id}/assign-courier": {
      "post": {
        "tags": [
          "Admin Shipments"
        ],
        "summary": "Assign courier",
        "description": "Assign courier. Controller: adminShipmentController.assignCourier. Authentication: Admin. API routes are rate limited and return standard error envelopes.",
        "operationId": "post_api_admin_shipments_id_assign_courier",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [
          {
            "name": "id",
            "in": "path",
            "required": true,
            "schema": {
              "type": "string"
            }
          }
        ],
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {
                "$ref": "#/components/schemas/CourierAssignRequest"
              },
              "examples": {
                "default": {
                  "summary": "CourierAssignRequest example",
                  "value": {
                    "provider": "manual",
                    "serviceName": "Manual Courier",
                    "trackingNumber": "MAN-123456",
                    "trackingUrl": "/track/MAN-123456",
                    "estimatedDelivery": "2026-07-15T10:00:00.000Z"
                  }
                }
              }
            }
          }
        },
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {
                        "shipmentNumber": "SHP-202607-000001",
                        "status": "CREATED"
                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {
                        "shipmentNumber": "SHP-202607-000001",
                        "status": "CREATED"
                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/admin/shipments/{id}/update-status": {
      "post": {
        "tags": [
          "Admin Shipments"
        ],
        "summary": "Update shipment status",
        "description": "Update shipment status. Controller: adminShipmentController.updateStatus. Authentication: Admin. API routes are rate limited and return standard error envelopes.",
        "operationId": "post_api_admin_shipments_id_update_status",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [
          {
            "name": "id",
            "in": "path",
            "required": true,
            "schema": {
              "type": "string"
            }
          }
        ],
        "requestBody": {
          "required": false,
          "content": {
            "application/json": {
              "schema": {
                "$ref": "#/components/schemas/StatusUpdateRequest"
              },
              "examples": {
                "default": {
                  "summary": "StatusUpdateRequest example",
                  "value": {
                    "status": "Processing",
                    "reason": "Status updated by admin"
                  }
                }
              }
            }
          }
        },
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {
                        "shipmentNumber": "SHP-202607-000001",
                        "status": "CREATED"
                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {
                        "shipmentNumber": "SHP-202607-000001",
                        "status": "CREATED"
                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/admin/shipments/{id}/cancel": {
      "post": {
        "tags": [
          "Admin Shipments"
        ],
        "summary": "Cancel shipment",
        "description": "Cancel shipment. Controller: adminShipmentController.cancelShipment. Authentication: Admin. API routes are rate limited and return standard error envelopes.",
        "operationId": "post_api_admin_shipments_id_cancel",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [
          {
            "name": "id",
            "in": "path",
            "required": true,
            "schema": {
              "type": "string"
            }
          }
        ],
        "requestBody": {
          "required": false,
          "content": {
            "application/json": {
              "schema": {
                "$ref": "#/components/schemas/ShipmentCancelRequest"
              },
              "examples": {
                "default": {
                  "summary": "ShipmentCancelRequest example",
                  "value": {
                    "reason": "Customer cancelled before dispatch"
                  }
                }
              }
            }
          }
        },
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {
                        "shipmentNumber": "SHP-202607-000001",
                        "status": "CREATED"
                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {
                        "shipmentNumber": "SHP-202607-000001",
                        "status": "CREATED"
                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/admin/analytics/dashboard": {
      "get": {
        "tags": [
          "Admin Analytics"
        ],
        "summary": "Analytics dashboard",
        "description": "Analytics dashboard. Controller: adminAnalyticsController.dashboard. Authentication: Admin. API routes are rate limited and return standard error envelopes.",
        "operationId": "get_api_admin_analytics_dashboard",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [
          {
            "name": "from",
            "in": "query",
            "required": false,
            "schema": {
              "type": "string",
              "format": "date-time"
            }
          },
          {
            "name": "to",
            "in": "query",
            "required": false,
            "schema": {
              "type": "string",
              "format": "date-time"
            }
          },
          {
            "name": "period",
            "in": "query",
            "required": false,
            "schema": {
              "type": "string",
              "enum": [
                "daily",
                "weekly",
                "monthly",
                "yearly"
              ]
            }
          }
        ],
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {
                        "report": "dashboard",
                        "generatedAt": "2026-07-10T00:00:00.000Z",
                        "data": {

                        }
                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {
                        "report": "dashboard",
                        "generatedAt": "2026-07-10T00:00:00.000Z",
                        "data": {

                        }
                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/admin/analytics/revenue": {
      "get": {
        "tags": [
          "Admin Analytics"
        ],
        "summary": "Revenue report",
        "description": "Revenue report. Controller: adminAnalyticsController.revenue. Authentication: Admin. API routes are rate limited and return standard error envelopes.",
        "operationId": "get_api_admin_analytics_revenue",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [
          {
            "name": "from",
            "in": "query",
            "required": false,
            "schema": {
              "type": "string",
              "format": "date-time"
            }
          },
          {
            "name": "to",
            "in": "query",
            "required": false,
            "schema": {
              "type": "string",
              "format": "date-time"
            }
          },
          {
            "name": "period",
            "in": "query",
            "required": false,
            "schema": {
              "type": "string",
              "enum": [
                "daily",
                "weekly",
                "monthly",
                "yearly"
              ]
            }
          },
          {
            "name": "page",
            "in": "query",
            "required": false,
            "schema": {
              "type": "integer",
              "minimum": 1,
              "default": 1
            }
          },
          {
            "name": "limit",
            "in": "query",
            "required": false,
            "schema": {
              "type": "integer",
              "minimum": 1,
              "maximum": 100,
              "default": 10
            }
          }
        ],
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {
                        "report": "dashboard",
                        "generatedAt": "2026-07-10T00:00:00.000Z",
                        "data": {

                        }
                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {
                        "report": "dashboard",
                        "generatedAt": "2026-07-10T00:00:00.000Z",
                        "data": {

                        }
                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/admin/analytics/books": {
      "get": {
        "tags": [
          "Admin Analytics"
        ],
        "summary": "Book sales report",
        "description": "Book sales report. Controller: adminAnalyticsController.books. Authentication: Admin. API routes are rate limited and return standard error envelopes.",
        "operationId": "get_api_admin_analytics_books",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [
          {
            "name": "from",
            "in": "query",
            "required": false,
            "schema": {
              "type": "string",
              "format": "date-time"
            }
          },
          {
            "name": "to",
            "in": "query",
            "required": false,
            "schema": {
              "type": "string",
              "format": "date-time"
            }
          },
          {
            "name": "page",
            "in": "query",
            "required": false,
            "schema": {
              "type": "integer",
              "minimum": 1,
              "default": 1
            }
          },
          {
            "name": "limit",
            "in": "query",
            "required": false,
            "schema": {
              "type": "integer",
              "minimum": 1,
              "maximum": 100,
              "default": 10
            }
          },
          {
            "name": "sort",
            "in": "query",
            "required": false,
            "schema": {
              "type": "string"
            }
          }
        ],
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {
                        "report": "dashboard",
                        "generatedAt": "2026-07-10T00:00:00.000Z",
                        "data": {

                        }
                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {
                        "report": "dashboard",
                        "generatedAt": "2026-07-10T00:00:00.000Z",
                        "data": {

                        }
                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/admin/analytics/payments": {
      "get": {
        "tags": [
          "Admin Analytics"
        ],
        "summary": "Payment metrics",
        "description": "Payment metrics. Controller: adminAnalyticsController.payments. Authentication: Admin. API routes are rate limited and return standard error envelopes.",
        "operationId": "get_api_admin_analytics_payments",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [
          {
            "name": "from",
            "in": "query",
            "required": false,
            "schema": {
              "type": "string",
              "format": "date-time"
            }
          },
          {
            "name": "to",
            "in": "query",
            "required": false,
            "schema": {
              "type": "string",
              "format": "date-time"
            }
          },
          {
            "name": "page",
            "in": "query",
            "required": false,
            "schema": {
              "type": "integer",
              "minimum": 1,
              "default": 1
            }
          },
          {
            "name": "limit",
            "in": "query",
            "required": false,
            "schema": {
              "type": "integer",
              "minimum": 1,
              "maximum": 100,
              "default": 10
            }
          }
        ],
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {
                        "report": "dashboard",
                        "generatedAt": "2026-07-10T00:00:00.000Z",
                        "data": {

                        }
                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {
                        "report": "dashboard",
                        "generatedAt": "2026-07-10T00:00:00.000Z",
                        "data": {

                        }
                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/admin/analytics/inventory": {
      "get": {
        "tags": [
          "Admin Analytics"
        ],
        "summary": "Inventory metrics",
        "description": "Inventory metrics. Controller: adminAnalyticsController.inventory. Authentication: Admin. API routes are rate limited and return standard error envelopes.",
        "operationId": "get_api_admin_analytics_inventory",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [
          {
            "name": "from",
            "in": "query",
            "required": false,
            "schema": {
              "type": "string",
              "format": "date-time"
            }
          },
          {
            "name": "to",
            "in": "query",
            "required": false,
            "schema": {
              "type": "string",
              "format": "date-time"
            }
          },
          {
            "name": "page",
            "in": "query",
            "required": false,
            "schema": {
              "type": "integer",
              "minimum": 1,
              "default": 1
            }
          },
          {
            "name": "limit",
            "in": "query",
            "required": false,
            "schema": {
              "type": "integer",
              "minimum": 1,
              "maximum": 100,
              "default": 10
            }
          }
        ],
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {
                        "report": "dashboard",
                        "generatedAt": "2026-07-10T00:00:00.000Z",
                        "data": {

                        }
                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {
                        "report": "dashboard",
                        "generatedAt": "2026-07-10T00:00:00.000Z",
                        "data": {

                        }
                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/admin/analytics/shipments": {
      "get": {
        "tags": [
          "Admin Analytics"
        ],
        "summary": "Shipment metrics",
        "description": "Shipment metrics. Controller: adminAnalyticsController.shipments. Authentication: Admin. API routes are rate limited and return standard error envelopes.",
        "operationId": "get_api_admin_analytics_shipments",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [
          {
            "name": "from",
            "in": "query",
            "required": false,
            "schema": {
              "type": "string",
              "format": "date-time"
            }
          },
          {
            "name": "to",
            "in": "query",
            "required": false,
            "schema": {
              "type": "string",
              "format": "date-time"
            }
          },
          {
            "name": "page",
            "in": "query",
            "required": false,
            "schema": {
              "type": "integer",
              "minimum": 1,
              "default": 1
            }
          },
          {
            "name": "limit",
            "in": "query",
            "required": false,
            "schema": {
              "type": "integer",
              "minimum": 1,
              "maximum": 100,
              "default": 10
            }
          }
        ],
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {
                        "report": "dashboard",
                        "generatedAt": "2026-07-10T00:00:00.000Z",
                        "data": {

                        }
                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {
                        "report": "dashboard",
                        "generatedAt": "2026-07-10T00:00:00.000Z",
                        "data": {

                        }
                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/admin/analytics/customers": {
      "get": {
        "tags": [
          "Admin Analytics"
        ],
        "summary": "Customer metrics",
        "description": "Customer metrics. Controller: adminAnalyticsController.customers. Authentication: Admin. API routes are rate limited and return standard error envelopes.",
        "operationId": "get_api_admin_analytics_customers",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [
          {
            "name": "from",
            "in": "query",
            "required": false,
            "schema": {
              "type": "string",
              "format": "date-time"
            }
          },
          {
            "name": "to",
            "in": "query",
            "required": false,
            "schema": {
              "type": "string",
              "format": "date-time"
            }
          },
          {
            "name": "page",
            "in": "query",
            "required": false,
            "schema": {
              "type": "integer",
              "minimum": 1,
              "default": 1
            }
          },
          {
            "name": "limit",
            "in": "query",
            "required": false,
            "schema": {
              "type": "integer",
              "minimum": 1,
              "maximum": 100,
              "default": 10
            }
          }
        ],
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {
                        "report": "dashboard",
                        "generatedAt": "2026-07-10T00:00:00.000Z",
                        "data": {

                        }
                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {
                        "report": "dashboard",
                        "generatedAt": "2026-07-10T00:00:00.000Z",
                        "data": {

                        }
                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/users/me/context": {
      "get": {
        "tags": [
          "Users"
        ],
        "summary": "Get current user session context & capabilities",
        "description": "Get current user session context & capabilities. Controller: userController.getUserContext. Authentication: Bearer. API routes are rate limited and return standard error envelopes. Returns user profile, capabilities, states, and features.paidAuthorDashboardAccess. When paidAuthorDashboardAccess=false, approved authors receive canAccessAuthorDashboard=true without fake entitlement records.",
        "operationId": "get_api_users_me_context",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [],
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {

                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/authors/me/royalty-settlements": {
      "get": {
        "tags": [
          "Royalty Settlements"
        ],
        "summary": "List author royalty settlements",
        "description": "List author royalty settlements. Controller: royaltySettlementController.getAuthorSettlements. Authentication: Bearer (Author Dashboard). API routes are rate limited and return standard error envelopes. Uses canonical author dashboard authorization gate.",
        "operationId": "get_api_authors_me_royalty_settlements",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [
          {
            "name": "page",
            "in": "query",
            "required": false,
            "schema": {
              "type": "integer",
              "minimum": 1,
              "default": 1
            }
          },
          {
            "name": "limit",
            "in": "query",
            "required": false,
            "schema": {
              "type": "integer",
              "minimum": 1,
              "maximum": 100,
              "default": 10
            }
          }
        ],
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {
                        "settlementNumber": "SETTLE-20260808-1001",
                        "status": "APPROVED",
                        "totalRoyalty": 500,
                        "currency": "INR"
                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {
                        "settlementNumber": "SETTLE-20260808-1001",
                        "status": "APPROVED",
                        "totalRoyalty": 500,
                        "currency": "INR"
                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/authors/me/royalty-settlements/{id}": {
      "get": {
        "tags": [
          "Royalty Settlements"
        ],
        "summary": "Get author settlement detail",
        "description": "Get author settlement detail. Controller: royaltySettlementController.getAuthorSettlementDetail. Authentication: Bearer (Author Dashboard). API routes are rate limited and return standard error envelopes. Uses canonical author dashboard authorization gate.",
        "operationId": "get_api_authors_me_royalty_settlements_id",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [
          {
            "name": "id",
            "in": "path",
            "required": true,
            "schema": {
              "type": "string"
            }
          }
        ],
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {
                        "settlementNumber": "SETTLE-20260808-1001",
                        "status": "APPROVED",
                        "totalRoyalty": 500,
                        "currency": "INR"
                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {
                        "settlementNumber": "SETTLE-20260808-1001",
                        "status": "APPROVED",
                        "totalRoyalty": 500,
                        "currency": "INR"
                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/admin/dashboard": {
      "get": {
        "tags": [
          "Admin Operations"
        ],
        "summary": "Get admin operational dashboard overview",
        "description": "Get admin operational dashboard overview. Controller: adminController.getAdminDashboardOverview. Authentication: Admin. API routes are rate limited and return standard error envelopes. Returns actionable operational counts across applications, publish requests, verification queues, orders, and settlements.",
        "operationId": "get_api_admin_dashboard",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [],
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {
                        "items": [],
                        "pagination": {
                          "total": 0,
                          "page": 1,
                          "limit": 20,
                          "pages": 0
                        }
                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {
                        "items": [],
                        "pagination": {
                          "total": 0,
                          "page": 1,
                          "limit": 20,
                          "pages": 0
                        }
                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/admin/authors/{authorId}": {
      "get": {
        "tags": [
          "Admin Operations"
        ],
        "summary": "Get admin author detail profile",
        "description": "Get admin author detail profile. Controller: adminController.getAdminAuthorDetail. Authentication: Admin. API routes are rate limited and return standard error envelopes. Aggregates author user profile, application record, entitlement status, book counts, publish requests, and royalty metrics.",
        "operationId": "get_api_admin_authors_authorId",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [
          {
            "name": "authorId",
            "in": "path",
            "required": true,
            "schema": {
              "type": "string"
            }
          }
        ],
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {
                        "items": [],
                        "pagination": {
                          "total": 0,
                          "page": 1,
                          "limit": 20,
                          "pages": 0
                        }
                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {
                        "items": [],
                        "pagination": {
                          "total": 0,
                          "page": 1,
                          "limit": 20,
                          "pages": 0
                        }
                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/admin/royalty-settlements/reconcile": {
      "get": {
        "tags": [
          "Royalty Settlements"
        ],
        "summary": "Reconcile royalty settlements and payouts",
        "description": "Reconcile royalty settlements and payouts. Controller: royaltySettlementController.reconcileSettlements. Authentication: Admin. API routes are rate limited and return standard error envelopes.",
        "operationId": "get_api_admin_royalty_settlements_reconcile",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [],
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {
                        "settlementNumber": "SETTLE-20260808-1001",
                        "status": "APPROVED",
                        "totalRoyalty": 500,
                        "currency": "INR"
                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {
                        "settlementNumber": "SETTLE-20260808-1001",
                        "status": "APPROVED",
                        "totalRoyalty": 500,
                        "currency": "INR"
                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/admin/royalty-settlements/preview": {
      "post": {
        "tags": [
          "Royalty Settlements"
        ],
        "summary": "Preview royalty settlement batch",
        "description": "Preview royalty settlement batch. Controller: royaltySettlementController.previewSettlement. Authentication: Admin. API routes are rate limited and return standard error envelopes.",
        "operationId": "post_api_admin_royalty_settlements_preview",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [],
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {
                "$ref": "#/components/schemas/SettlementPreviewRequest"
              },
              "examples": {
                "default": {
                  "summary": "SettlementPreviewRequest example",
                  "value": {
                    "authorId": "66b4f5a2a44d2c0012a9c105",
                    "from": "2026-08-01T00:00:00.000Z",
                    "to": "2026-08-31T23:59:59.999Z"
                  }
                }
              }
            }
          }
        },
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {
                        "settlementNumber": "SETTLE-20260808-1001",
                        "status": "APPROVED",
                        "totalRoyalty": 500,
                        "currency": "INR"
                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {
                        "settlementNumber": "SETTLE-20260808-1001",
                        "status": "APPROVED",
                        "totalRoyalty": 500,
                        "currency": "INR"
                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/admin/royalty-settlements": {
      "post": {
        "tags": [
          "Royalty Settlements"
        ],
        "summary": "Create draft royalty settlement batch",
        "description": "Create draft royalty settlement batch. Controller: royaltySettlementController.createDraftSettlement. Authentication: Admin. API routes are rate limited and return standard error envelopes.",
        "operationId": "post_api_admin_royalty_settlements",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [],
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {
                "$ref": "#/components/schemas/SettlementCreateRequest"
              },
              "examples": {
                "default": {
                  "summary": "SettlementCreateRequest example",
                  "value": {
                    "authorId": "66b4f5a2a44d2c0012a9c105",
                    "periodStart": "2026-08-01T00:00:00.000Z",
                    "periodEnd": "2026-08-31T23:59:59.999Z"
                  }
                }
              }
            }
          }
        },
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {
                        "settlementNumber": "SETTLE-20260808-1001",
                        "status": "APPROVED",
                        "totalRoyalty": 500,
                        "currency": "INR"
                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {
                        "settlementNumber": "SETTLE-20260808-1001",
                        "status": "APPROVED",
                        "totalRoyalty": 500,
                        "currency": "INR"
                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      },
      "get": {
        "tags": [
          "Royalty Settlements"
        ],
        "summary": "List royalty settlements for admin",
        "description": "List royalty settlements for admin. Controller: royaltySettlementController.listSettlementsForAdmin. Authentication: Admin. API routes are rate limited and return standard error envelopes.",
        "operationId": "get_api_admin_royalty_settlements",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [
          {
            "name": "authorId",
            "in": "query",
            "required": false,
            "schema": {
              "type": "string"
            }
          },
          {
            "name": "status",
            "in": "query",
            "required": false,
            "schema": {
              "type": "string"
            }
          },
          {
            "name": "page",
            "in": "query",
            "required": false,
            "schema": {
              "type": "integer",
              "minimum": 1,
              "default": 1
            }
          },
          {
            "name": "limit",
            "in": "query",
            "required": false,
            "schema": {
              "type": "integer",
              "minimum": 1,
              "maximum": 100,
              "default": 10
            }
          }
        ],
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {
                        "settlementNumber": "SETTLE-20260808-1001",
                        "status": "APPROVED",
                        "totalRoyalty": 500,
                        "currency": "INR"
                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {
                        "settlementNumber": "SETTLE-20260808-1001",
                        "status": "APPROVED",
                        "totalRoyalty": 500,
                        "currency": "INR"
                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/admin/royalty-settlements/{id}": {
      "get": {
        "tags": [
          "Royalty Settlements"
        ],
        "summary": "Get settlement detail for admin",
        "description": "Get settlement detail for admin. Controller: royaltySettlementController.getSettlementDetailForAdmin. Authentication: Admin. API routes are rate limited and return standard error envelopes.",
        "operationId": "get_api_admin_royalty_settlements_id",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [
          {
            "name": "id",
            "in": "path",
            "required": true,
            "schema": {
              "type": "string"
            }
          }
        ],
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {
                        "settlementNumber": "SETTLE-20260808-1001",
                        "status": "APPROVED",
                        "totalRoyalty": 500,
                        "currency": "INR"
                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {
                        "settlementNumber": "SETTLE-20260808-1001",
                        "status": "APPROVED",
                        "totalRoyalty": 500,
                        "currency": "INR"
                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/admin/royalty-settlements/{id}/approve": {
      "post": {
        "tags": [
          "Royalty Settlements"
        ],
        "summary": "Approve draft royalty settlement batch",
        "description": "Approve draft royalty settlement batch. Controller: royaltySettlementController.approveSettlement. Authentication: Admin. API routes are rate limited and return standard error envelopes. Atomically locks source sale lines at database level via unique claim index.",
        "operationId": "post_api_admin_royalty_settlements_id_approve",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [
          {
            "name": "id",
            "in": "path",
            "required": true,
            "schema": {
              "type": "string"
            }
          }
        ],
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {
                        "settlementNumber": "SETTLE-20260808-1001",
                        "status": "APPROVED",
                        "totalRoyalty": 500,
                        "currency": "INR"
                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {
                        "settlementNumber": "SETTLE-20260808-1001",
                        "status": "APPROVED",
                        "totalRoyalty": 500,
                        "currency": "INR"
                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/admin/royalty-settlements/{id}/mark-paid": {
      "post": {
        "tags": [
          "Royalty Settlements"
        ],
        "summary": "Record manual payout for approved settlement",
        "description": "Record manual payout for approved settlement. Controller: royaltySettlementController.markPaid. Authentication: Admin. API routes are rate limited and return standard error envelopes. Requires manual transaction reference. Amount is server-owned.",
        "operationId": "post_api_admin_royalty_settlements_id_mark_paid",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [
          {
            "name": "id",
            "in": "path",
            "required": true,
            "schema": {
              "type": "string"
            }
          }
        ],
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {
                "$ref": "#/components/schemas/SettlementMarkPaidRequest"
              },
              "examples": {
                "default": {
                  "summary": "SettlementMarkPaidRequest example",
                  "value": {
                    "paymentMethod": "MANUAL_BANK_TRANSFER",
                    "transactionReference": "BANK-UTR-123456789",
                    "paidAt": "2026-09-02T10:30:00.000Z",
                    "notes": "Paid through manual bank transfer."
                  }
                }
              }
            }
          }
        },
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {
                        "settlementNumber": "SETTLE-20260808-1001",
                        "status": "APPROVED",
                        "totalRoyalty": 500,
                        "currency": "INR"
                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {
                        "settlementNumber": "SETTLE-20260808-1001",
                        "status": "APPROVED",
                        "totalRoyalty": 500,
                        "currency": "INR"
                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    },
    "/api/admin/royalty-settlements/{id}/cancel": {
      "post": {
        "tags": [
          "Royalty Settlements"
        ],
        "summary": "Cancel royalty settlement batch",
        "description": "Cancel royalty settlement batch. Controller: royaltySettlementController.cancelSettlement. Authentication: Admin. API routes are rate limited and return standard error envelopes.",
        "operationId": "post_api_admin_royalty_settlements_id_cancel",
        "security": [
          {
            "bearerAuth": []
          }
        ],
        "parameters": [
          {
            "name": "id",
            "in": "path",
            "required": true,
            "schema": {
              "type": "string"
            }
          }
        ],
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {
                "$ref": "#/components/schemas/SettlementCancelRequest"
              },
              "examples": {
                "default": {
                  "summary": "SettlementCancelRequest example",
                  "value": {
                    "reason": "Incorrect settlement period selected."
                  }
                }
              }
            }
          }
        },
        "responses": {
          "200": {
            "description": "Successful response.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "success": {
                    "value": {
                      "success": true,
                      "data": {
                        "settlementNumber": "SETTLE-20260808-1001",
                        "status": "APPROVED",
                        "totalRoyalty": 500,
                        "currency": "INR"
                      }
                    }
                  }
                }
              }
            }
          },
          "201": {
            "description": "Created successfully where applicable.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiSuccess"
                },
                "examples": {
                  "created": {
                    "value": {
                      "success": true,
                      "data": {
                        "settlementNumber": "SETTLE-20260808-1001",
                        "status": "APPROVED",
                        "totalRoyalty": 500,
                        "currency": "INR"
                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "429": {
            "$ref": "#/components/responses/RateLimited"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          },
          "SettlementPreviewRequest": {
            "type": "object",
            "required": [
              "authorId"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "from": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window start."
              },
              "to": {
                "type": "string",
                "format": "date-time",
                "description": "Optional sales window end."
              }
            }
          },
          "SettlementCreateRequest": {
            "type": "object",
            "required": [
              "authorId",
              "periodStart",
              "periodEnd"
            ],
            "properties": {
              "authorId": {
                "type": "string",
                "description": "Author user ObjectId."
              },
              "periodStart": {
                "type": "string",
                "format": "date-time"
              },
              "periodEnd": {
                "type": "string",
                "format": "date-time"
              }
            }
          },
          "SettlementMarkPaidRequest": {
            "type": "object",
            "required": [
              "transactionReference"
            ],
            "properties": {
              "paymentMethod": {
                "type": "string",
                "enum": [
                  "MANUAL_BANK_TRANSFER",
                  "MANUAL_UPI",
                  "CHEQUE",
                  "OTHER"
                ],
                "default": "MANUAL_BANK_TRANSFER"
              },
              "transactionReference": {
                "type": "string",
                "description": "External/manual payout reference recorded by admin."
              },
              "paidAt": {
                "type": "string",
                "format": "date-time",
                "description": "Optional. Defaults to current server time."
              },
              "notes": {
                "type": "string"
              }
            }
          },
          "SettlementCancelRequest": {
            "type": "object",
            "properties": {
              "reason": {
                "type": "string",
                "default": "Cancelled by admin"
              }
            }
          }
        }
      }
    }
  },
  "components": {
    "securitySchemes": {
      "bearerAuth": {
        "type": "http",
        "scheme": "bearer",
        "bearerFormat": "JWT"
      }
    },
    "schemas": {
      "ApiSuccess": {
        "type": "object",
        "properties": {
          "success": {
            "type": "boolean",
            "examples": [true]
          },
          "data": {
            "type": "object"
          },
          "message": {
            "type": "string"
          }
        }
      },
      "Pagination": {
        "type": "object",
        "properties": {
          "total": {
            "type": "integer",
            "minimum": 0
          },
          "page": {
            "type": "integer",
            "minimum": 1
          },
          "limit": {
            "type": "integer",
            "minimum": 1
          },
          "pages": {
            "type": "integer",
            "minimum": 0
          }
        }
      },
      "PaginatedSuccess": {
        "type": "object",
        "properties": {
          "success": {
            "type": "boolean",
            "examples": [true]
          },
          "data": {
            "type": "array",
            "items": {
              "type": "object"
            }
          },
          "pagination": {
            "$ref": "#/components/schemas/Pagination"
          }
        }
      },
      "ApiError": {
        "type": "object",
        "required": [
          "message"
        ],
        "properties": {
          "success": {
            "type": "boolean",
            "examples": [false]
          },
          "status": {
            "type": "string",
            "examples": [
              "error"
            ]
          },
          "message": {
            "type": "string"
          },
          "stack": {
            "type": "string",
            "description": "Development only."
          }
        }
      },
      "User": {
        "type": "object",
        "properties": {
          "_id": {
            "type": "string"
          },
          "name": {
            "type": "string"
          },
          "email": {
            "type": "string",
            "format": "email"
          },
          "role": {
            "type": "string",
            "enum": [
              "visitor",
              "reader",
              "author",
              "admin"
            ]
          },
          "profilePicture": {
            "type": "string"
          },
          "createdAt": {
            "type": "string",
            "format": "date-time"
          },
          "updatedAt": {
            "type": "string",
            "format": "date-time"
          }
        }
      },
      "Category": {
        "type": "object",
        "properties": {
          "_id": {
            "type": "string"
          },
          "name": {
            "type": "string"
          },
          "slug": {
            "type": "string"
          },
          "description": {
            "type": "string"
          },
          "shortDescription": {
            "type": "string"
          },
          "image": {
            "type": "string"
          },
          "banner": {
            "type": "string"
          },
          "icon": {
            "type": "string"
          },
          "seoTitle": {
            "type": "string"
          },
          "seoDescription": {
            "type": "string"
          },
          "parentCategory": {
            "type": "string",
            "nullable": true
          },
          "sortOrder": {
            "type": "number"
          },
          "bookCount": {
            "type": "integer"
          },
          "featured": {
            "type": "boolean"
          },
          "active": {
            "type": "boolean"
          },
          "isActive": {
            "type": "boolean",
            "description": "Legacy compatibility field synchronized with active."
          },
          "metadata": {
            "type": "object",
            "additionalProperties": true
          },
          "createdAt": {
            "type": "string",
            "format": "date-time"
          },
          "updatedAt": {
            "type": "string",
            "format": "date-time"
          }
        }
      },
      "Content": {
        "type": "object",
        "properties": {
          "key": {
            "type": "string",
            "default": "global"
          },
          "hero": {
            "type": "object",
            "additionalProperties": true
          },
          "about": {
            "type": "object",
            "additionalProperties": true
          },
          "contact": {
            "type": "object",
            "additionalProperties": true
          },
          "faq": {
            "type": "array",
            "items": {
              "type": "object",
              "additionalProperties": true
            }
          },
          "footer": {
            "type": "object",
            "additionalProperties": true
          },
          "socialLinks": {
            "type": "object",
            "additionalProperties": true
          },
          "seo": {
            "type": "object",
            "additionalProperties": true
          },
          "announcements": {
            "type": "array",
            "items": {
              "type": "object",
              "additionalProperties": true
            }
          },
          "siteSettings": {
            "type": "object",
            "additionalProperties": true
          },
          "homeTitle": {
            "type": "string"
          },
          "homeSubtitle": {
            "type": "string"
          },
          "publishTitle": {
            "type": "string"
          },
          "publishSubtitle": {
            "type": "string"
          },
          "packagesJson": {
            "type": "string"
          },
          "updatedAt": {
            "type": "string",
            "format": "date-time"
          }
        }
      },
      "Book": {
        "type": "object",
        "properties": {
          "_id": {
            "type": "string"
          },
          "title": {
            "type": "string"
          },
          "slug": {
            "type": "string"
          },
          "description": {
            "type": "string"
          },
          "author": {
            "oneOf": [
              {
                "type": "string"
              },
              {
                "$ref": "#/components/schemas/User"
              }
            ]
          },
          "category": {
            "oneOf": [
              {
                "type": "string"
              },
              {
                "$ref": "#/components/schemas/Category"
              }
            ]
          },
          "price": {
            "type": "number"
          },
          "royaltyPercentage": {
            "type": "number",
            "minimum": 0,
            "maximum": 100,
            "default": 0
          },
          "coverImage": {
            "type": "string"
          },
          "stock": {
            "type": "integer"
          },
          "reservedStock": {
            "type": "integer"
          },
          "ratings": {
            "type": "number"
          },
          "reviewCount": {
            "type": "integer"
          },
          "status": {
            "type": "string",
            "enum": [
              "draft",
              "published",
              "archived"
            ]
          },
          "discountPrice": {
            "type": "number"
          },
          "isBestseller": {
            "type": "boolean"
          },
          "isFeatured": {
            "type": "boolean"
          },
          "isNewRelease": {
            "type": "boolean"
          },
          "isbn": {
            "type": "string"
          },
          "pages": {
            "type": "integer"
          },
          "format": {
            "type": "string",
            "enum": [
              "hardcover",
              "paperback",
              "ebook",
              "audiobook"
            ]
          },
          "createdAt": {
            "type": "string",
            "format": "date-time"
          },
          "updatedAt": {
            "type": "string",
            "format": "date-time"
          }
        }
      },
      "OrderItem": {
        "type": "object",
        "properties": {
          "book": {
            "oneOf": [
              {
                "type": "string"
              },
              {
                "$ref": "#/components/schemas/Book"
              }
            ]
          },
          "quantity": {
            "type": "integer",
            "minimum": 1
          },
          "price": {
            "type": "number"
          }
        }
      },
      "Order": {
        "type": "object",
        "properties": {
          "_id": {
            "type": "string"
          },
          "orderNumber": {
            "type": "string"
          },
          "user": {
            "oneOf": [
              {
                "type": "string"
              },
              {
                "$ref": "#/components/schemas/User"
              }
            ]
          },
          "items": {
            "type": "array",
            "items": {
              "$ref": "#/components/schemas/OrderItem"
            }
          },
          "totalPrice": {
            "type": "number"
          },
          "status": {
            "type": "string"
          },
          "isPaid": {
            "type": "boolean"
          },
          "paidAt": {
            "type": "string",
            "format": "date-time"
          },
          "paymentMethod": {
            "type": "string"
          },
          "utr": {
            "type": "string"
          },
          "payment": {
            "type": "string"
          },
          "qrCode": {
            "type": "string"
          },
          "qrCodeDataUrl": {
            "type": "string"
          },
          "createdAt": {
            "type": "string",
            "format": "date-time"
          }
        }
      },
      "Payment": {
        "type": "object",
        "properties": {
          "_id": {
            "type": "string"
          },
          "order": {
            "type": "string"
          },
          "user": {
            "type": "string"
          },
          "amount": {
            "type": "number"
          },
          "currency": {
            "type": "string",
            "examples": [
              "INR"
            ]
          },
          "provider": {
            "type": "string"
          },
          "paymentMethod": {
            "type": "string"
          },
          "status": {
            "type": "string"
          },
          "utr": {
            "type": "string"
          },
          "successfulPayment": {
            "type": "boolean"
          },
          "activeIntent": {
            "type": "boolean"
          },
          "expiresAt": {
            "type": "string",
            "format": "date-time"
          },
          "verifiedAt": {
            "type": "string",
            "format": "date-time"
          }
        }
      },
      "PaymentLedger": {
        "type": "object",
        "properties": {
          "ledgerId": {
            "type": "string"
          },
          "paymentId": {
            "type": "string"
          },
          "orderId": {
            "type": "string"
          },
          "userId": {
            "type": "string"
          },
          "eventType": {
            "type": "string"
          },
          "previousStatus": {
            "type": "string"
          },
          "currentStatus": {
            "type": "string"
          },
          "amount": {
            "type": "number"
          },
          "currency": {
            "type": "string"
          },
          "provider": {
            "type": "string"
          },
          "reference": {
            "type": "string"
          },
          "createdAt": {
            "type": "string",
            "format": "date-time"
          }
        }
      },
      "InventoryReservation": {
        "type": "object",
        "properties": {
          "_id": {
            "type": "string"
          },
          "order": {
            "type": "string"
          },
          "payment": {
            "type": "string"
          },
          "book": {
            "type": "string"
          },
          "quantity": {
            "type": "integer"
          },
          "status": {
            "type": "string"
          },
          "reservedAt": {
            "type": "string",
            "format": "date-time"
          },
          "expiresAt": {
            "type": "string",
            "format": "date-time"
          }
        }
      },
      "InventoryLedger": {
        "type": "object",
        "properties": {
          "_id": {
            "type": "string"
          },
          "reservation": {
            "type": "string"
          },
          "order": {
            "type": "string"
          },
          "payment": {
            "type": "string"
          },
          "book": {
            "type": "string"
          },
          "eventType": {
            "type": "string"
          },
          "quantity": {
            "type": "integer"
          },
          "createdAt": {
            "type": "string",
            "format": "date-time"
          }
        }
      },
      "Invoice": {
        "type": "object",
        "properties": {
          "_id": {
            "type": "string"
          },
          "invoiceNumber": {
            "type": "string"
          },
          "order": {
            "type": "string"
          },
          "payment": {
            "type": "string"
          },
          "customer": {
            "type": "string"
          },
          "items": {
            "type": "array",
            "items": {
              "type": "object"
            }
          },
          "total": {
            "type": "number"
          },
          "currency": {
            "type": "string"
          },
          "status": {
            "type": "string"
          },
          "generatedAt": {
            "type": "string",
            "format": "date-time"
          }
        }
      },
      "Shipment": {
        "type": "object",
        "properties": {
          "_id": {
            "type": "string"
          },
          "shipmentNumber": {
            "type": "string"
          },
          "order": {
            "type": "string"
          },
          "invoice": {
            "type": "string"
          },
          "status": {
            "type": "string"
          },
          "courier": {
            "type": "object",
            "additionalProperties": true
          },
          "tracking": {
            "type": "array",
            "items": {
              "type": "object"
            }
          },
          "createdAt": {
            "type": "string",
            "format": "date-time"
          }
        }
      },
      "ShipmentLedger": {
        "type": "object",
        "properties": {
          "_id": {
            "type": "string"
          },
          "shipment": {
            "type": "string"
          },
          "order": {
            "type": "string"
          },
          "eventType": {
            "type": "string"
          },
          "previousStatus": {
            "type": "string"
          },
          "currentStatus": {
            "type": "string"
          },
          "createdAt": {
            "type": "string",
            "format": "date-time"
          }
        }
      },
      "Notification": {
        "type": "object",
        "properties": {
          "_id": {
            "type": "string"
          },
          "user": {
            "type": "string"
          },
          "eventType": {
            "type": "string"
          },
          "channel": {
            "type": "string"
          },
          "subject": {
            "type": "string"
          },
          "status": {
            "type": "string"
          },
          "retryCount": {
            "type": "integer"
          },
          "sentAt": {
            "type": "string",
            "format": "date-time"
          }
        }
      },
      "AnalyticsEvent": {
        "type": "object",
        "properties": {
          "eventId": {
            "type": "string"
          },
          "eventType": {
            "type": "string"
          },
          "occurredAt": {
            "type": "string",
            "format": "date-time"
          },
          "bucketDay": {
            "type": "string"
          },
          "amount": {
            "type": "number"
          },
          "quantity": {
            "type": "number"
          },
          "metadata": {
            "type": "object",
            "additionalProperties": true
          }
        }
      },
      "RegisterRequest": {
        "type": "object",
        "required": [
          "name",
          "email",
          "password"
        ],
        "properties": {
          "name": {
            "type": "string",
            "minLength": 2
          },
          "email": {
            "type": "string",
            "format": "email"
          },
          "password": {
            "type": "string",
            "minLength": 6
          }
        }
      },
      "LoginRequest": {
        "type": "object",
        "required": [
          "email",
          "password"
        ],
        "properties": {
          "email": {
            "type": "string",
            "format": "email"
          },
          "password": {
            "type": "string"
          }
        }
      },
      "GoogleLoginRequest": {
        "type": "object",
        "required": [
          "credential"
        ],
        "additionalProperties": false,
        "properties": {
          "credential": {
            "type": "string",
            "maxLength": 4096,
            "description": "Google Identity Services ID token. Backend verifies signature, expiry, issuer, and audience against GOOGLE_CLIENT_ID."
          }
        }
      },
      "OrderCreateRequest": {
        "type": "object",
        "required": [
          "items",
          "shippingAddress"
        ],
        "properties": {
          "items": {
            "type": "array",
            "minItems": 1,
            "items": {
              "type": "object",
              "required": [
                "book",
                "quantity"
              ],
              "properties": {
                "book": {
                  "type": "string",
                  "description": "Book ObjectId."
                },
                "quantity": {
                  "type": "integer",
                  "minimum": 1
                }
              }
            }
          },
          "shippingAddress": {
            "type": "object",
            "required": [
              "fullName",
              "addressLine1",
              "city",
              "postalCode",
              "country"
            ],
            "properties": {
              "fullName": {
                "type": "string"
              },
              "addressLine1": {
                "type": "string"
              },
              "addressLine2": {
                "type": "string"
              },
              "city": {
                "type": "string"
              },
              "postalCode": {
                "type": "string"
              },
              "country": {
                "type": "string"
              }
            }
          },
          "paymentMethod": {
            "type": "string",
            "default": "UPI",
            "examples": [
              "UPI"
            ]
          }
        }
      },
      "PaymentVerificationRequest": {
        "type": "object",
        "required": [
          "utr"
        ],
        "properties": {
          "utr": {
            "type": "string",
            "pattern": "^[A-Z0-9-]{6,64}$"
          }
        }
      },
      "StatusUpdateRequest": {
        "type": "object",
        "required": [
          "status"
        ],
        "properties": {
          "status": {
            "type": "string"
          },
          "reason": {
            "type": "string"
          },
          "description": {
            "type": "string"
          },
          "location": {
            "type": "string"
          },
          "occurredAt": {
            "type": "string",
            "format": "date-time"
          }
        }
      },
      "RejectPaymentRequest": {
        "type": "object",
        "properties": {
          "reason": {
            "type": "string",
            "maxLength": 500
          }
        }
      },
      "UserUpdateRequest": {
        "type": "object",
        "properties": {
          "name": {
            "type": "string"
          },
          "bio": {
            "type": "string",
            "description": "Accepted by controller but currently not persisted in User schema."
          },
          "profilePicture": {
            "type": "string",
            "format": "uri"
          }
        }
      },
      "WishlistRequest": {
        "type": "object",
        "required": [
          "bookId"
        ],
        "properties": {
          "bookId": {
            "type": "string"
          }
        }
      },
      "AuthorBookCreateRequest": {
        "type": "object",
        "required": [
          "title",
          "description",
          "category"
        ],
        "properties": {
          "title": {
            "type": "string"
          },
          "description": {
            "type": "string"
          },
          "category": {
            "type": "string",
            "description": "Category ObjectId."
          },
          "mrp": {
            "type": "number",
            "minimum": 0,
            "description": "Canonical book price. Preferred field for new frontend code."
          },
          "price": {
            "type": "number",
            "minimum": 0,
            "description": "Legacy compatibility alias for mrp. If supplied with mrp, both values must match."
          },
          "format": {
            "type": "string",
            "enum": [
              "hardcover",
              "paperback",
              "ebook",
              "audiobook"
            ],
            "default": "paperback"
          },
          "coverImage": {
            "type": "string",
            "format": "uri"
          },
          "isbn": {
            "type": "string"
          },
          "pages": {
            "type": "integer",
            "minimum": 1
          }
        }
      },
      "AuthorBookUpdateRequest": {
        "type": "object",
        "properties": {
          "title": {
            "type": "string"
          },
          "description": {
            "type": "string"
          },
          "category": {
            "type": "string",
            "description": "Category ObjectId."
          },
          "mrp": {
            "type": "number",
            "minimum": 0,
            "description": "Canonical book price. Preferred field for new frontend code."
          },
          "price": {
            "type": "number",
            "minimum": 0,
            "description": "Legacy compatibility alias for mrp. If supplied with mrp, both values must match."
          },
          "format": {
            "type": "string",
            "enum": [
              "hardcover",
              "paperback",
              "ebook",
              "audiobook"
            ]
          },
          "coverImage": {
            "type": "string",
            "format": "uri"
          },
          "isbn": {
            "type": "string"
          },
          "pages": {
            "type": "integer",
            "minimum": 1
          }
        }
      },
      "AdminBookCreateRequest": {
        "type": "object",
        "description": "Admin book creation payload. slug is server-owned, generated from title, URL-safe, and unique. Frontend should not send slug. Book.mrp is canonical; price is a temporary compatibility alias.",
        "required": [
          "title",
          "description",
          "category",
          "mrp"
        ],
        "properties": {
          "title": {
            "type": "string"
          },
          "description": {
            "type": "string"
          },
          "author": {
            "type": "string",
            "description": "Optional author ObjectId. Defaults to current admin user when omitted."
          },
          "category": {
            "type": "string",
            "description": "Category ObjectId."
          },
          "mrp": {
            "type": "number",
            "minimum": 0,
            "description": "Canonical book price. Preferred field for new frontend code."
          },
          "price": {
            "type": "number",
            "minimum": 0,
            "description": "Legacy compatibility alias for mrp. If supplied with mrp, both values must match."
          },
          "royaltyPercentage": {
            "type": "number",
            "minimum": 0,
            "maximum": 100,
            "default": 0
          },
          "coverImage": {
            "type": "string",
            "format": "uri"
          },
          "stock": {
            "type": "integer",
            "minimum": 0
          },
          "reservedStock": {
            "type": "integer",
            "minimum": 0
          },
          "status": {
            "type": "string",
            "enum": [
              "draft",
              "published",
              "archived"
            ],
            "default": "draft"
          },
          "discountPrice": {
            "type": "number"
          },
          "isBestseller": {
            "type": "boolean"
          },
          "isFeatured": {
            "type": "boolean"
          },
          "isNewRelease": {
            "type": "boolean"
          },
          "isbn": {
            "type": "string"
          },
          "pages": {
            "type": "integer",
            "minimum": 1
          },
          "format": {
            "type": "string",
            "enum": [
              "hardcover",
              "paperback",
              "ebook",
              "audiobook"
            ],
            "default": "paperback"
          }
        }
      },
      "AdminBookUpdateRequest": {
        "type": "object",
        "description": "Admin book update payload. slug is stable after creation and remains server-owned. Title updates do not regenerate slug.",
        "properties": {
          "title": {
            "type": "string"
          },
          "description": {
            "type": "string"
          },
          "author": {
            "type": "string"
          },
          "category": {
            "type": "string"
          },
          "mrp": {
            "type": "number",
            "minimum": 0,
            "description": "Canonical book price. Preferred field for new frontend code."
          },
          "price": {
            "type": "number",
            "minimum": 0,
            "description": "Legacy compatibility alias for mrp. If supplied with mrp, both values must match."
          },
          "royaltyPercentage": {
            "type": "number",
            "minimum": 0,
            "maximum": 100,
            "default": 0
          },
          "coverImage": {
            "type": "string",
            "format": "uri"
          },
          "stock": {
            "type": "integer",
            "minimum": 0
          },
          "reservedStock": {
            "type": "integer",
            "minimum": 0
          },
          "status": {
            "type": "string",
            "enum": [
              "draft",
              "published",
              "archived"
            ]
          },
          "discountPrice": {
            "type": "number"
          },
          "isBestseller": {
            "type": "boolean"
          },
          "isFeatured": {
            "type": "boolean"
          },
          "isNewRelease": {
            "type": "boolean"
          },
          "isbn": {
            "type": "string"
          },
          "pages": {
            "type": "integer",
            "minimum": 1
          },
          "format": {
            "type": "string",
            "enum": [
              "hardcover",
              "paperback",
              "ebook",
              "audiobook"
            ]
          }
        }
      },
      "BookCreateRequest": {
        "type": "object",
        "description": "Backward-compatible alias for AdminBookCreateRequest. New docs should prefer AdminBookCreateRequest or AuthorBookCreateRequest.",
        "allOf": [
          {
            "$ref": "#/components/schemas/AdminBookCreateRequest"
          }
        ]
      },
      "BookUpdateRequest": {
        "type": "object",
        "description": "Backward-compatible alias for AdminBookUpdateRequest. New docs should prefer AdminBookUpdateRequest or AuthorBookUpdateRequest.",
        "allOf": [
          {
            "$ref": "#/components/schemas/AdminBookUpdateRequest"
          }
        ]
      },
      "BookSubmissionRequest": {
        "type": "object",
        "required": [
          "fileUrl"
        ],
        "properties": {
          "fileUrl": {
            "type": "string",
            "format": "uri",
            "description": "Uploaded manuscript URL. documentUrl or manuscriptUrl are accepted compatibility aliases."
          },
          "documentUrl": {
            "type": "string",
            "format": "uri",
            "description": "Compatibility alias for fileUrl."
          },
          "manuscriptUrl": {
            "type": "string",
            "format": "uri",
            "description": "Compatibility alias for fileUrl."
          },
          "packageId": {
            "type": "string",
            "description": "Optional PublishPackage ObjectId. Defaults to the first active package when omitted."
          },
          "genre": {
            "type": "string",
            "description": "Optional. Defaults from category name or General."
          },
          "wordCount": {
            "type": "integer",
            "minimum": 1,
            "description": "Optional. Defaults from pages * 300 or 25000."
          },
          "pages": {
            "type": "integer",
            "minimum": 1,
            "description": "Optional helper for deriving wordCount when wordCount is omitted."
          }
        }
      },
      "EditorialReasonRequest": {
        "type": "object",
        "properties": {
          "reason": {
            "type": "string",
            "description": "Optional admin reason. Runtime supplies a default when omitted."
          }
        }
      },
      "EditorialNotesRequest": {
        "type": "object",
        "properties": {
          "notes": {
            "type": "string",
            "description": "Optional admin notes. Runtime supplies a default when omitted."
          }
        }
      },
      "CategoryCreateRequest": {
        "type": "object",
        "required": [
          "name"
        ],
        "properties": {
          "name": {
            "type": "string"
          },
          "slug": {
            "type": "string",
            "description": "Optional. Generated from name when omitted."
          },
          "description": {
            "type": "string"
          },
          "shortDescription": {
            "type": "string"
          },
          "image": {
            "type": "string",
            "format": "uri"
          },
          "banner": {
            "type": "string",
            "format": "uri"
          },
          "icon": {
            "type": "string"
          },
          "seoTitle": {
            "type": "string"
          },
          "seoDescription": {
            "type": "string"
          },
          "parentCategory": {
            "type": "string",
            "nullable": true
          },
          "sortOrder": {
            "type": "number",
            "default": 0
          },
          "featured": {
            "type": "boolean",
            "default": false
          },
          "active": {
            "type": "boolean",
            "default": true
          },
          "metadata": {
            "type": "object",
            "additionalProperties": true
          }
        }
      },
      "CategoryUpdateRequest": {
        "type": "object",
        "properties": {
          "name": {
            "type": "string"
          },
          "slug": {
            "type": "string"
          },
          "description": {
            "type": "string"
          },
          "shortDescription": {
            "type": "string"
          },
          "image": {
            "type": "string",
            "format": "uri"
          },
          "banner": {
            "type": "string",
            "format": "uri"
          },
          "icon": {
            "type": "string"
          },
          "seoTitle": {
            "type": "string"
          },
          "seoDescription": {
            "type": "string"
          },
          "parentCategory": {
            "type": "string",
            "nullable": true
          },
          "sortOrder": {
            "type": "number"
          },
          "featured": {
            "type": "boolean"
          },
          "active": {
            "type": "boolean"
          },
          "metadata": {
            "type": "object",
            "additionalProperties": true
          }
        }
      },
      "CategoryStatusRequest": {
        "type": "object",
        "required": [
          "active"
        ],
        "properties": {
          "active": {
            "type": "boolean"
          }
        }
      },
      "RefreshTokenRequest": {
        "type": "object",
        "properties": {
          "refreshToken": {
            "type": "string",
            "description": "Opaque refresh token issued by login/register/reset-password."
          }
        }
      },
      "LogoutRequest": {
        "type": "object",
        "properties": {
          "refreshToken": {
            "type": "string",
            "description": "Refresh token to revoke. Optional when bearer token is supplied."
          },
          "all": {
            "type": "boolean",
            "default": false,
            "description": "Revoke all active sessions for the authenticated user."
          }
        }
      },
      "ResetPasswordRequest": {
        "type": "object",
        "required": [
          "password"
        ],
        "properties": {
          "password": {
            "type": "string",
            "minLength": 6
          }
        }
      },
      "ChangePasswordRequest": {
        "type": "object",
        "required": [
          "currentPassword",
          "password"
        ],
        "properties": {
          "currentPassword": {
            "type": "string",
            "minLength": 6
          },
          "password": {
            "type": "string",
            "minLength": 6
          }
        }
      },
      "ForgotPasswordRequest": {
        "type": "object",
        "required": [
          "email"
        ],
        "properties": {
          "email": {
            "type": "string",
            "format": "email"
          }
        }
      },
      "PasswordResetRequest": {
        "type": "object",
        "required": [
          "password"
        ],
        "properties": {
          "password": {
            "type": "string",
            "minLength": 6
          }
        }
      },
      "AuthorApplicationRequest": {
        "type": "object",
        "properties": {
          "penName": {
            "type": "string"
          },
          "bio": {
            "type": "string"
          },
          "portfolioUrl": {
            "type": "string",
            "format": "uri"
          },
          "experience": {
            "type": "string"
          }
        }
      },
      "AuthorApplicationStatusRequest": {
        "type": "object",
        "required": [
          "status"
        ],
        "properties": {
          "status": {
            "type": "string",
            "enum": [
              "approved",
              "rejected"
            ]
          }
        }
      },
      "ReviewRequest": {
        "type": "object",
        "properties": {
          "book": {
            "type": "string"
          },
          "rating": {
            "type": "integer",
            "minimum": 1,
            "maximum": 5
          },
          "comment": {
            "type": "string"
          }
        }
      },
      "ReviewCreateRequest": {
        "type": "object",
        "required": [
          "book",
          "rating",
          "comment"
        ],
        "properties": {
          "book": {
            "type": "string"
          },
          "rating": {
            "type": "integer",
            "minimum": 1,
            "maximum": 5
          },
          "comment": {
            "type": "string"
          }
        }
      },
      "ReviewUpdateRequest": {
        "type": "object",
        "properties": {
          "rating": {
            "type": "integer",
            "minimum": 1,
            "maximum": 5
          },
          "comment": {
            "type": "string"
          }
        }
      },
      "ReviewModerationRequest": {
        "type": "object",
        "required": [
          "status"
        ],
        "properties": {
          "status": {
            "type": "string",
            "enum": [
              "approved",
              "pending",
              "rejected"
            ]
          }
        }
      },
      "ContentUpdateRequest": {
        "type": "object",
        "properties": {
          "hero": {
            "type": "object",
            "additionalProperties": true
          },
          "about": {
            "type": "object",
            "additionalProperties": true
          },
          "contact": {
            "type": "object",
            "additionalProperties": true
          },
          "faq": {
            "type": "array",
            "items": {
              "type": "object",
              "additionalProperties": true
            }
          },
          "footer": {
            "type": "object",
            "additionalProperties": true
          },
          "socialLinks": {
            "type": "object",
            "additionalProperties": true
          },
          "seo": {
            "type": "object",
            "additionalProperties": true
          },
          "announcements": {
            "type": "array",
            "items": {
              "type": "object",
              "additionalProperties": true
            }
          },
          "siteSettings": {
            "type": "object",
            "additionalProperties": true
          },
          "homeTitle": {
            "type": "string"
          },
          "homeSubtitle": {
            "type": "string"
          },
          "publishTitle": {
            "type": "string"
          },
          "publishSubtitle": {
            "type": "string"
          },
          "packagesJson": {
            "type": "string"
          }
        }
      },
      "AdminUserUpdateRequest": {
        "type": "object",
        "properties": {
          "role": {
            "type": "string",
            "enum": [
              "user",
              "visitor",
              "reader",
              "author",
              "admin"
            ],
            "description": "user is normalized to reader."
          },
          "isActive": {
            "type": "boolean"
          },
          "status": {
            "type": "string",
            "enum": [
              "Active",
              "Suspended"
            ],
            "description": "Frontend compatibility alias for isActive."
          }
        }
      },
      "UserRoleRequest": {
        "type": "object",
        "required": [
          "role"
        ],
        "properties": {
          "role": {
            "type": "string",
            "enum": [
              "user",
              "visitor",
              "reader",
              "author",
              "admin"
            ],
            "description": "user is normalized to reader for frontend compatibility."
          }
        }
      },
      "UserStatusRequest": {
        "type": "object",
        "required": [
          "isActive"
        ],
        "properties": {
          "isActive": {
            "type": "boolean"
          }
        }
      },
      "AdminRoleUpdateRequest": {
        "type": "object",
        "required": [
          "role"
        ],
        "properties": {
          "role": {
            "type": "string",
            "enum": [
              "user",
              "visitor",
              "reader",
              "author",
              "admin"
            ],
            "description": "user is normalized to reader for frontend compatibility."
          }
        }
      },
      "AdminUserStatusRequest": {
        "type": "object",
        "required": [
          "isActive"
        ],
        "properties": {
          "isActive": {
            "type": "boolean"
          }
        }
      },
      "AdminPasswordResetRequest": {
        "type": "object",
        "required": [
          "password"
        ],
        "properties": {
          "password": {
            "type": "string",
            "minLength": 6
          }
        }
      },
      "PublishRequestCreate": {
        "type": "object",
        "required": [
          "title",
          "genre",
          "wordCount",
          "packageId",
          "fileUrl"
        ],
        "properties": {
          "title": {
            "type": "string"
          },
          "genre": {
            "type": "string"
          },
          "wordCount": {
            "type": "integer",
            "minimum": 1
          },
          "packageId": {
            "type": "string",
            "description": "PublishPackage ObjectId."
          },
          "fileUrl": {
            "type": "string",
            "format": "uri"
          }
        }
      },
      "CourierAssignRequest": {
        "type": "object",
        "properties": {
          "provider": {
            "type": "string",
            "default": "manual"
          },
          "serviceName": {
            "type": "string",
            "default": "Manual Courier"
          },
          "trackingNumber": {
            "type": "string"
          },
          "trackingUrl": {
            "type": "string"
          },
          "estimatedDelivery": {
            "type": "string",
            "format": "date-time"
          }
        }
      },
      "PaymentActionRequest": {
        "type": "object",
        "properties": {
          "reason": {
            "type": "string",
            "maxLength": 500
          },
          "metadata": {
            "type": "object",
            "additionalProperties": true
          }
        }
      },
      "QRRegenerateRequest": {
        "type": "object",
        "properties": {
          "force": {
            "type": "boolean",
            "default": true
          },
          "reason": {
            "type": "string",
            "default": "Admin QR regeneration"
          }
        }
      },
      "NotificationRetryRequest": {
        "type": "object",
        "properties": {
          "reason": {
            "type": "string"
          },
          "force": {
            "type": "boolean",
            "default": false
          }
        }
      },
      "ShipmentCancelRequest": {
        "type": "object",
        "properties": {
          "reason": {
            "type": "string"
          }
        }
      },
      "AuthorAccessPlanRequest": {
        "type": "object",
        "required": [
          "amount"
        ],
        "properties": {
          "name": {
            "type": "string",
            "default": "Author Dashboard Access"
          },
          "description": {
            "type": "string",
            "default": "One-time author dashboard operational access plan"
          },
          "amount": {
            "type": "number",
            "minimum": 0
          },
          "currency": {
            "type": "string",
            "default": "INR"
          },
          "status": {
            "type": "string",
            "enum": [
              "DRAFT",
              "ACTIVE",
              "ARCHIVED"
            ],
            "default": "ACTIVE"
          },
          "version": {
            "type": "integer",
            "minimum": 1
          }
        }
      },
      "AuthorAccessGrantRequest": {
        "type": "object",
        "required": [
          "userId"
        ],
        "properties": {
          "userId": {
            "type": "string",
            "description": "Author user ObjectId to grant dashboard entitlement."
          },
          "reason": {
            "type": "string",
            "description": "Optional audit reason."
          }
        }
      },
      "AuthorAccessReasonRequest": {
        "type": "object",
        "properties": {
          "reason": {
            "type": "string",
            "description": "Optional audit reason. userId comes from the URL path."
          }
        }
      },
      "SettlementPreviewRequest": {
        "type": "object",
        "required": [
          "authorId"
        ],
        "properties": {
          "authorId": {
            "type": "string",
            "description": "Author user ObjectId."
          },
          "from": {
            "type": "string",
            "format": "date-time",
            "description": "Optional sales window start."
          },
          "to": {
            "type": "string",
            "format": "date-time",
            "description": "Optional sales window end."
          }
        }
      },
      "SettlementCreateRequest": {
        "type": "object",
        "required": [
          "authorId",
          "periodStart",
          "periodEnd"
        ],
        "properties": {
          "authorId": {
            "type": "string",
            "description": "Author user ObjectId."
          },
          "periodStart": {
            "type": "string",
            "format": "date-time"
          },
          "periodEnd": {
            "type": "string",
            "format": "date-time"
          }
        }
      },
      "SettlementMarkPaidRequest": {
        "type": "object",
        "required": [
          "transactionReference"
        ],
        "properties": {
          "paymentMethod": {
            "type": "string",
            "enum": [
              "MANUAL_BANK_TRANSFER",
              "MANUAL_UPI",
              "CHEQUE",
              "OTHER"
            ],
            "default": "MANUAL_BANK_TRANSFER"
          },
          "transactionReference": {
            "type": "string",
            "description": "External/manual payout reference recorded by admin."
          },
          "paidAt": {
            "type": "string",
            "format": "date-time",
            "description": "Optional. Defaults to current server time."
          },
          "notes": {
            "type": "string"
          }
        }
      },
      "SettlementCancelRequest": {
        "type": "object",
        "properties": {
          "reason": {
            "type": "string",
            "default": "Cancelled by admin"
          }
        }
      },
      "MultipartImageRequest": {
        "type": "object",
        "required": [
          "image"
        ],
        "properties": {
          "image": {
            "type": "string",
            "format": "binary",
            "description": "Multipart field name: image. Allowed MIME types: image/jpeg, image/png, image/webp, image/gif. Default max size: 25MB unless UPLOAD_MAX_BYTES is configured."
          }
        }
      },
      "MultipartDocumentRequest": {
        "type": "object",
        "required": [
          "document"
        ],
        "properties": {
          "document": {
            "type": "string",
            "format": "binary",
            "description": "Multipart field name: document. Allowed MIME types: application/pdf, application/msword, application/vnd.openxmlformats-officedocument.wordprocessingml.document. Default max size: 25MB unless UPLOAD_MAX_BYTES is configured."
          }
        }
      }
    },
    "responses": {
      "BadRequest": {
        "description": "Invalid input or business rule failure.",
        "content": {
          "application/json": {
            "schema": {
              "$ref": "#/components/schemas/ApiError"
            },
            "examples": {
              "error": {
                "value": {
                  "success": false,
                  "message": "Error message"
                }
              }
            }
          }
        }
      },
      "Unauthorized": {
        "description": "Missing or invalid bearer token.",
        "content": {
          "application/json": {
            "schema": {
              "$ref": "#/components/schemas/ApiError"
            }
          }
        }
      },
      "Forbidden": {
        "description": "Authenticated user does not have the required role.",
        "content": {
          "application/json": {
            "schema": {
              "$ref": "#/components/schemas/ApiError"
            }
          }
        }
      },
      "NotFound": {
        "description": "Resource or route not found.",
        "content": {
          "application/json": {
            "schema": {
              "$ref": "#/components/schemas/ApiError"
            }
          }
        }
      },
      "Conflict": {
        "description": "Duplicate resource or state conflict.",
        "content": {
          "application/json": {
            "schema": {
              "$ref": "#/components/schemas/ApiError"
            },
            "examples": {
              "duplicate": {
                "value": {
                  "success": false,
                  "message": "Resource already exists"
                }
              }
            }
          }
        }
      },
      "PayloadTooLarge": {
        "description": "Request body or upload exceeds configured size limits.",
        "content": {
          "application/json": {
            "schema": {
              "$ref": "#/components/schemas/ApiError"
            },
            "examples": {
              "tooLarge": {
                "value": {
                  "success": false,
                  "message": "File too large"
                }
              }
            }
          }
        }
      },
      "UnsupportedMediaType": {
        "description": "Unsupported upload MIME type or file extension.",
        "content": {
          "application/json": {
            "schema": {
              "$ref": "#/components/schemas/ApiError"
            },
            "examples": {
              "unsupported": {
                "value": {
                  "success": false,
                  "message": "Unsupported file type"
                }
              }
            }
          }
        }
      },
      "UnprocessableEntity": {
        "description": "Validation passed transport parsing but failed business validation.",
        "content": {
          "application/json": {
            "schema": {
              "$ref": "#/components/schemas/ApiError"
            }
          }
        }
      },
      "RateLimited": {
        "description": "Rate limit exceeded.",
        "headers": {
          "RateLimit": {
            "schema": {
              "type": "string"
            },
            "description": "Standard rate limit policy header."
          },
          "RateLimit-Policy": {
            "schema": {
              "type": "string"
            },
            "description": "Configured rate-limit policy."
          }
        },
        "content": {
          "application/json": {
            "schema": {
              "$ref": "#/components/schemas/ApiError"
            },
            "examples": {
              "rateLimited": {
                "value": {
                  "success": false,
                  "message": "Too many requests from this IP, please try again later."
                }
              }
            }
          }
        }
      },
      "ServiceUnavailable": {
        "description": "Required runtime dependency is unavailable or not configured.",
        "content": {
          "application/json": {
            "schema": {
              "$ref": "#/components/schemas/ApiError"
            }
          }
        }
      },
      "InternalServerError": {
        "description": "Unexpected server error.",
        "content": {
          "application/json": {
            "schema": {
              "$ref": "#/components/schemas/ApiError"
            }
          }
        }
      }
    }
  },
  "security": [
    {
      "bearerAuth": []
    }
  ],
  "x-event-catalog": {
    "PaymentIntentCreated": {
      "producer": "PaymentService",
      "entity": "Payment",
      "description": "A payment intent was created for an order."
    },
    "QRCodeGenerated": {
      "producer": "PaymentService",
      "entity": "Payment",
      "description": "A dynamic QR was generated or regenerated for an active payment intent."
    },
    "PaymentSubmitted": {
      "producer": "PaymentService",
      "entity": "Payment",
      "description": "A customer submitted a manual payment reference."
    },
    "PaymentVerified": {
      "producer": "PaymentService",
      "entity": "Payment",
      "description": "An authorized actor verified a payment."
    },
    "PaymentRejected": {
      "producer": "PaymentService",
      "entity": "Payment",
      "description": "An authorized actor rejected a payment."
    },
    "PaymentExpired": {
      "producer": "PaymentService",
      "entity": "Payment",
      "description": "A payment intent expired."
    },
    "PaymentCancelled": {
      "producer": "PaymentService",
      "entity": "Payment",
      "description": "A payment intent was cancelled."
    },
    "PaymentFailed": {
      "producer": "PaymentService",
      "entity": "Payment",
      "description": "A payment attempt failed."
    },
    "OrderCreated": {
      "producer": "OrderPaymentBridgeService",
      "entity": "Order",
      "description": "An order was created with payment and inventory orchestration."
    },
    "OrderCancelled": {
      "producer": "OrderPaymentBridgeService",
      "entity": "Order",
      "description": "An order cancellation released runtime resources."
    },
    "InventoryReserved": {
      "producer": "InventoryService",
      "entity": "InventoryReservation",
      "description": "Inventory was reserved for checkout."
    },
    "InventoryReleased": {
      "producer": "InventoryService",
      "entity": "InventoryReservation",
      "description": "A reservation was released."
    },
    "InventoryDeducted": {
      "producer": "InventoryService",
      "entity": "InventoryReservation",
      "description": "Reserved inventory was converted to stock deduction."
    },
    "InventoryExpired": {
      "producer": "InventoryService",
      "entity": "InventoryReservation",
      "description": "A reservation expired."
    },
    "LedgerCreated": {
      "producer": "PaymentService|InventoryService",
      "entity": "Ledger",
      "description": "An immutable ledger entry was written."
    },
    "AdminApprovedPayment": {
      "producer": "AdminOperationsService",
      "entity": "Payment",
      "description": "An admin approved a payment through operations tooling."
    },
    "AdminRejectedPayment": {
      "producer": "AdminOperationsService",
      "entity": "Payment",
      "description": "An admin rejected a payment through operations tooling."
    },
    "AdminCancelledPayment": {
      "producer": "AdminOperationsService",
      "entity": "Payment",
      "description": "An admin cancelled a payment intent."
    },
    "AdminExpiredPayment": {
      "producer": "AdminOperationsService",
      "entity": "Payment",
      "description": "An admin expired a payment intent."
    },
    "AdminRecreatedQR": {
      "producer": "AdminOperationsService",
      "entity": "Payment",
      "description": "An admin regenerated a payment QR."
    },
    "InvoiceGenerated": {
      "producer": "InvoiceService",
      "entity": "Invoice",
      "description": "An official invoice was generated for a verified payment."
    },
    "ShipmentCreated": {
      "producer": "ShipmentService",
      "entity": "Shipment",
      "description": "A shipment was created for a paid and invoiced order."
    },
    "CourierAssigned": {
      "producer": "ShipmentService",
      "entity": "Shipment",
      "description": "A courier was assigned to a shipment."
    },
    "ShipmentDispatched": {
      "producer": "ShipmentService",
      "entity": "Shipment",
      "description": "A shipment entered dispatch or transit."
    },
    "ShipmentDelivered": {
      "producer": "ShipmentService",
      "entity": "Shipment",
      "description": "A shipment was delivered."
    },
    "ShipmentCancelled": {
      "producer": "ShipmentService",
      "entity": "Shipment",
      "description": "A shipment was cancelled before dispatch completion."
    },
    "CategoryCreated": {
      "producer": "CategoryService",
      "entity": "Category",
      "description": "A product category was created."
    },
    "CategoryUpdated": {
      "producer": "CategoryService",
      "entity": "Category",
      "description": "A product category was updated."
    },
    "CategoryDeleted": {
      "producer": "CategoryService",
      "entity": "Category",
      "description": "A product category was soft deleted."
    },
    "CategoryActivated": {
      "producer": "CategoryService",
      "entity": "Category",
      "description": "A product category was activated."
    },
    "CategoryDeactivated": {
      "producer": "CategoryService",
      "entity": "Category",
      "description": "A product category was deactivated."
    }
  }
}