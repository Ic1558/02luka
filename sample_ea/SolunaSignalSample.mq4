#property strict
#property copyright "Soluna Labs"
#property link      "https://paula-agent.trade.soluna.dev"

#include "..\\integrations\\mt4\\SolunaSignalClient.mqh"

input string InpApiBaseUrl = "https://paula-agent.trade.soluna.dev";
input string InpApiKey     = "replace-with-api-key";
input string InpAccountId  = "DEMO-ACC-1";
input int    InpPollSeconds = 60;

SolunaSignalClient g_client;

int OnInit()
  {
   if(InpPollSeconds < 5)
     {
      Print("[PaulaSample] Poll period too small. Using 5 seconds instead.");
      InpPollSeconds = 5;
     }
   g_client.Configure(InpApiBaseUrl, InpApiKey, 7000);
   EventSetTimer(InpPollSeconds);
   Print("[PaulaSample] Initialized. Polling every ", InpPollSeconds, " seconds.");
   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason)
  {
   EventKillTimer();
  }

void OnTimer()
  {
   string response="";
   string error="";
   if(g_client.GetNextSignal(InpAccountId, response, "", "pending", error))
     {
      if(StringLen(response)==0)
        {
         Print("[PaulaSample] No signal available (204).");
         return;
        }
      Print("[PaulaSample] Received signal payload: ", response);

      // TODO: add your execution logic here. For now we immediately acknowledge.
      string signalId = ExtractJsonString(response, "id");
      if(StringLen(signalId)==0)
        {
         Print("[PaulaSample] Unable to extract signal id from payload.");
         return;
        }

      string ackError="";
      if(g_client.AcknowledgeSignal(signalId, InpAccountId, "SampleEA", "Auto-acknowledged", ackError))
         Print("[PaulaSample] Acknowledged signal ", signalId);
      else
         Print("[PaulaSample] Failed to acknowledge signal ", signalId, ": ", ackError);
     }
   else
     {
      Print("[PaulaSample] Poll failed: ", error);
     }
  }

string ExtractJsonString(const string json,const string key)
  {
   string needle = "\""+key+"\"";
   int pos = StringFind(json, needle);
   if(pos==-1)
      return "";
   pos = StringFind(json, ":", pos);
   if(pos==-1)
      return "";
   int start = StringFind(json, "\"", pos);
   if(start==-1)
      return "";
   start += 1;
   int end = StringFind(json, "\"", start);
   if(end==-1)
      return "";
   return StringSubstr(json, start, end-start);
  }
