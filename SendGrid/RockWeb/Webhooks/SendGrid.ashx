<%@ WebHandler Language="C#" Class="SendGrid" %>
// <copyright>
// Copyright 2013 by the Spark Development Network
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
// </copyright>
//

using System;
using System.Web;
using System.IO;
using System.Text;
using Rock;
using Rock.Model;
using Rock.Workflow.Action;
using Sendgrid.Webhooks.Events;

public class SendGrid : IHttpHandler
{
    private HttpRequest _request;
    private HttpResponse _response;
    private int _transactionCount;

    public void ProcessRequest( HttpContext context )
    {
        _request = context.Request;
        _response = context.Response;

        _response.ContentType = "text/plain";

        if ( !( _request.HttpMethod == "POST" && _request.ContentType.Contains( "application/json" ) ) )
        {
            _response.Write( "Invalid request type." );
            return;
        }

        if ( _request != null )
        {
            string postedData = GetDocumentContents( _request );

            var rockContext = new Rock.Data.RockContext();

            var communicationRecipientService = new CommunicationRecipientService( rockContext );

            var parser = new Sendgrid.Webhooks.Service.WebhookParser();
            var events = parser.ParseEvents( postedData );

            if ( events != null )
            {
                int unsavedCommunicationCount = 0;
                foreach ( var item in events )
                {
                    _transactionCount++;
                    unsavedCommunicationCount++;
                    // Process a SendEmailWithEvents workflow action 
                    if ( item.UniqueParameters.ContainsKey( "workflow_action_guid" ) )
                    {
                        var actionGuid = item.UniqueParameters["workflow_action_guid"].AsGuidOrNull();
                            string status = string.Empty;
                            switch ( item.EventType )
                            {
                                case WebhookEventType.Delivered: status = SendEmailWithEvents.SENT_STATUS; break;
                                case WebhookEventType.Open: status = SendEmailWithEvents.OPENED_STATUS; break;
                                case WebhookEventType.Click: status = SendEmailWithEvents.CLICKED_STATUS; break;
                                case WebhookEventType.SpamReport: 
                                case WebhookEventType.Bounce:
                                case WebhookEventType.Dropped:
                                case WebhookEventType.Unsubscribe:
                                case WebhookEventType.Group_Unsubscribe:
                                    status = SendEmailWithEvents.FAILED_STATUS; break;
                                case WebhookEventType.Group_Resubscribe:
                                    break;
                            }

                        if (actionGuid != null && !string.IsNullOrWhiteSpace(status))
                        {
                            SendEmailWithEvents.UpdateEmailStatus(actionGuid.Value, status, item.EventType.ConvertToString().SplitCase(), rockContext, true);
                        }
                    }

                    // Process a regular communication recipient  
                    if (item.UniqueParameters.ContainsKey("communication_recipient_guid"))
                    {
                        Guid communicationRecipientGuid;
                        if (Guid.TryParse(item.UniqueParameters["communication_recipient_guid"], out communicationRecipientGuid))
                        {
                            var communicationRecipient = communicationRecipientService.Get(communicationRecipientGuid);

                            if (communicationRecipient != null)
                            {
                                switch (item.EventType)
                                {
                                    case WebhookEventType.Delivered:
                                        communicationRecipient.Status = CommunicationRecipientStatus.Delivered;
                                        communicationRecipient.StatusNote =
                                            string.Format("Confirmed delivered by SendGrid at {0}",
                                                item.TimeStamp.ToString("o"));
                                        break;
                                    case WebhookEventType.Open:
                                        communicationRecipient.Status = CommunicationRecipientStatus.Opened;
                                        var openEvent = item as OpenEvent;
                                        if (openEvent != null)
                                        {
                                            communicationRecipient.OpenedDateTime = openEvent.TimeStamp;
                                            communicationRecipient.OpenedClient = openEvent.UserAgent.Truncate(197) ??
                                                                                  "Unknown";
                                            var openActivity = new CommunicationRecipientActivity
                                            {
                                                ActivityType = "Opened",
                                                ActivityDateTime = item.TimeStamp,
                                                ActivityDetail =
                                                    string.Format("Opened from {0} ({1})", openEvent.UserAgent ?? "unknown",
                                                        openEvent.Ip).Truncate(2197)
                                            };
                                            communicationRecipient.Activities.Add(openActivity);
                                        }
                                        break;
                                    case WebhookEventType.Click:
                                        var clickActivity = new CommunicationRecipientActivity {ActivityType = "Click"};
                                        var clickEvent = item as ClickEvent;
                                        clickActivity.ActivityDateTime = item.TimeStamp;
                                        if (clickEvent != null)
                                        {
                                            clickActivity.ActivityDetail =
                                                string.Format("Clicked the address {0} from {1} using {2}", clickEvent.Url,
                                                    clickEvent.Ip, clickEvent.UserAgent).Truncate(2197);
                                        }
                                        communicationRecipient.Activities.Add(clickActivity);
                                        break;
                                }
                            }
                        }

                        // save every 100 changes
                        if (unsavedCommunicationCount >= 100)
                        {
                            rockContext.SaveChanges();
                            unsavedCommunicationCount = 0;
                        }
                    }

                    // final save
                    rockContext.SaveChanges();

                    // if bounced process the bounced message
                    if (item.EventType == WebhookEventType.Bounce)
                    {
                        var bounceEvent = item as BounceEvent;
                        if (bounceEvent != null)
                        {
                            string bounceDescription = bounceEvent.Reason ?? string.Empty;
                            if (!string.IsNullOrEmpty(item.Email))
                            {
                                Rock.Communication.Email.ProcessBounce(item.Email, Rock.Communication.BounceType.HardBounce, bounceDescription, item.TimeStamp);
                            }
                        }
                    }
                }
            }
        }

        _response.Write(string.Format("Success: Processed {0} transactions.", _transactionCount));

        _response.StatusCode = 200;
    }


    public bool IsReusable
    {
        get { return false; }
    }

    private static string GetDocumentContents(HttpRequest request)
    {
        string documentContents;
        using (var receiveStream = request.InputStream)
        {
            using (var readStream = new StreamReader(receiveStream, Encoding.UTF8))
            {
                documentContents = readStream.ReadToEnd();
            }
        }
        return documentContents;
    }
}
