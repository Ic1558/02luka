#property strict

class SolunaSignalClient
  {
private:
   string   m_baseUrl;
   string   m_apiKey;
   int      m_timeout;
   int      m_priceDigits;
   int      m_volumeDigits;
   string   m_userAgent;

public:
   void Configure(const string baseUrl,const string apiKey,const int timeoutMilliseconds=5000)
     {
      m_baseUrl      = NormalizeBaseUrl(baseUrl);
      m_apiKey       = apiKey;
      m_timeout      = timeoutMilliseconds;
      m_priceDigits  = 5;
      m_volumeDigits = 2;
      m_userAgent    = "SolunaSignalClient/1.0";
     }

   void SetTimeout(const int timeoutMilliseconds)
     {
      m_timeout = timeoutMilliseconds;
     }

   void SetPriceDigits(const int digits)
     {
      if(digits>=0) m_priceDigits = digits;
     }

   void SetVolumeDigits(const int digits)
     {
      if(digits>=0) m_volumeDigits = digits;
     }

   bool GetNextSignal(const string accountId,string &payload,const string symbolFilter="",const string status="pending",string &error)
     {
      string query="";
      AddQueryParam(query,"account_id",accountId);
      AddQueryParam(query,"symbol",symbolFilter);
      AddQueryParam(query,"status",status);
      int statusCode=0;
      return HttpRequest("GET","/signal",query,"",payload,statusCode,error);
     }

   bool AcknowledgeSignal(const string signalId,const string accountId,const string strategy="",const string notes="",string &error)
     {
      string body="{"+
         QuotePair("account_id",accountId);
      if(StringLen(strategy)>0)
         body += ","+QuotePair("strategy",strategy);
      if(StringLen(notes)>0)
         body += ","+QuotePair("notes",notes);
      body += "}";
      string payload="";
      int statusCode=0;
      string path="/signal/"+UrlEncode(signalId)+"/ack";
      bool ok=HttpRequest("POST",path,"",body,payload,statusCode,error);
      if(ok && statusCode!=202)
        {
         error = "Unexpected status "+IntegerToString(statusCode)+": "+payload;
         return false;
        }
      return ok;
     }

   bool RejectSignal(const string signalId,const string accountId,const string reasonCode,const string notes="",string &error)
     {
      string body="{"+
         QuotePair("account_id",accountId)+","+
         QuotePair("reason_code",reasonCode);
      if(StringLen(notes)>0)
         body += ","+QuotePair("notes",notes);
      body += "}";
      string payload="";
      int statusCode=0;
      string path="/signal/"+UrlEncode(signalId)+"/reject";
      bool ok=HttpRequest("POST",path,"",body,payload,statusCode,error);
      if(ok && statusCode!=202)
        {
         error = "Unexpected status "+IntegerToString(statusCode)+": "+payload;
         return false;
        }
      return ok;
     }

   bool ReportFill(const string signalId,const string accountId,const double fillPrice,const double fillVolume,const datetime executedAt,string &error)
     {
      string body="{"+
         QuotePair("account_id",accountId)+","+
         NumericPair("fill_price",DoubleToString(fillPrice,m_priceDigits))+","+
         NumericPair("fill_volume",DoubleToString(fillVolume,m_volumeDigits))+","+
         QuotePair("executed_at",ToIso8601(executedAt))+"}";
      string payload="";
      int statusCode=0;
      string path="/signal/"+UrlEncode(signalId)+"/fill";
      bool ok=HttpRequest("POST",path,"",body,payload,statusCode,error);
      if(ok && statusCode!=201)
        {
         error = "Unexpected status "+IntegerToString(statusCode)+": "+payload;
         return false;
        }
      return ok;
     }

   bool SendHeartbeat(const string accountId,const string status="online",const double latencyMs=0.0,string &error)
     {
      string body="{"+QuotePair("status",status);
      if(latencyMs>0.0)
         body += ","+NumericPair("latency_ms",DoubleToString(latencyMs,1));
      body += "}";
      string payload="";
      int statusCode=0;
      string path="/accounts/"+UrlEncode(accountId)+"/heartbeat";
      bool ok=HttpRequest("POST",path,"",body,payload,statusCode,error);
      if(ok && statusCode!=204)
        {
         error = "Unexpected status "+IntegerToString(statusCode)+": "+payload;
         return false;
        }
      return ok;
     }

private:
   string NormalizeBaseUrl(string baseUrl)
     {
      string trimmed=baseUrl;
      while(StringLen(trimmed)>0 && StringSubstr(trimmed,StringLen(trimmed)-1,1)=="/")
         trimmed=StringSubstr(trimmed,0,StringLen(trimmed)-1);
      return trimmed;
     }

   string BuildUrl(const string path,const string query)
     {
      string normalizedPath=path;
      if(StringLen(normalizedPath)==0 || StringSubstr(normalizedPath,0,1)!="/")
         normalizedPath="/"+normalizedPath;
      string url=m_baseUrl+normalizedPath;
      if(StringLen(query)>0)
         url+="?"+query;
      return url;
     }

   bool HttpRequest(const string method,const string path,const string query,const string body,string &payload,int &statusCode,string &error)
     {
      error="";
      string url=BuildUrl(path,query);
      char requestBody[];
      ArrayResize(requestBody,0);
      if(StringLen(body)>0)
         StringToCharArray(body,requestBody,0,WHOLE_ARRAY,CP_UTF8);
      char response[];
      string headers="Content-Type: application/json\r\nAccept: application/json\r\n"+
         "User-Agent: "+m_userAgent+"\r\n";
      if(StringLen(m_apiKey)>0)
         headers += "X-API-Key: "+m_apiKey+"\r\n";
      string resultHeaders="";
      ResetLastError();
      int bytes=WebRequest(method,url,headers,m_timeout,requestBody,response,resultHeaders);
      if(bytes==-1)
        {
         int err=GetLastError();
         error = "WebRequest failed ("+IntegerToString(err)+")";
         return false;
        }
      statusCode = ExtractStatusCode(resultHeaders);
      payload=CharArrayToString(response,0,bytes,CP_UTF8);
      if(statusCode<200 || statusCode>=300)
        {
         if(StringLen(error)==0)
            error = "HTTP "+IntegerToString(statusCode)+": "+payload;
         return false;
        }
      return true;
     }

   void AddQueryParam(string &query,const string key,const string value)
     {
      if(StringLen(value)==0)
         return;
      if(StringLen(query)>0)
         query += "&";
      query += key+"="+UrlEncode(value);
     }

   string UrlEncode(const string value)
     {
      string result="";
      for(int i=0;i<StringLen(value);i++)
        {
         ushort ch=(ushort)StringGetCharacter(value,i);
         bool safe=(ch>='0' && ch<='9') || (ch>='A' && ch<='Z') || (ch>='a' && ch<='z') || ch=='-' || ch=='_' || ch=='.' || ch=='~';
         if(safe)
            result += StringSubstr(value,i,1);
         else if(ch==' ')
            result += "%20";
         else
            result += StringFormat("%%%02X",ch);
        }
      return result;
     }

   string QuotePair(const string key,const string value)
     {
      return "\""+key+"\":\""+EscapeJson(value)+"\"";
     }

   string NumericPair(const string key,const string value)
     {
      return "\""+key+"\":"+value;
     }

   string EscapeJson(const string value)
     {
      string result="";
      for(int i=0;i<StringLen(value);i++)
        {
         ushort ch=(ushort)StringGetCharacter(value,i);
         if(ch=='"')
            result += "\\\"";
         else if(ch=='\\')
            result += "\\\\";
         else if(ch=='\n')
            result += "\\n";
         else if(ch=='\r')
            result += "\\r";
         else if(ch=='\t')
            result += "\\t";
         else
            result += StringSubstr(value,i,1);
        }
      return result;
     }

   string ToIso8601(const datetime value)
     {
      string datePart=TimeToString(value,TIME_DATE);
      StringReplace(datePart,".","-");
      string timePart=TimeToString(value,TIME_SECONDS);
      return datePart+"T"+timePart+"Z";
     }

   int ExtractStatusCode(const string headers)
     {
      if(StringLen(headers)==0)
         return 0;
      int lineEnd=StringFind(headers,"\r\n");
      string statusLine=(lineEnd==-1)?headers:StringSubstr(headers,0,lineEnd);
      int firstSpace=StringFind(statusLine," ");
      if(firstSpace==-1)
         return 0;
      int secondSpace=StringFind(statusLine," ",firstSpace+1);
      string code=(secondSpace==-1)?StringSubstr(statusLine,firstSpace+1):StringSubstr(statusLine,firstSpace+1,secondSpace-firstSpace-1);
      return (int)StringToInteger(code);
     }
  };
