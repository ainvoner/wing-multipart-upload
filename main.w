bring cloud;

let api = new cloud.Api(
  cors: true,
  corsOptions: cloud.ApiCorsOptions {
    allowOrigin: "*",
    allowMethods: [cloud.HttpMethod.GET, cloud.HttpMethod.POST, cloud.HttpMethod.OPTIONS],
    allowHeaders: ["Content-Type"],
    allowCredentials: false,
    exposeHeaders: ["Content-Type"],
    maxAge: 600s
  }
);

let multipartBucket = new cloud.Bucket();

let handleCompleteUpload = inflight (req: cloud.ApiRequest) => {
    let json_data = Json.parse(req.body ?? "");
    let s3_key = str.fromJson(json_data["s3_key"]);
    let upload_id = str.fromJson(json_data["upload_id"]);
    let parts = num.fromJson(json_data["parts"]);
    multipartBucket.completeMultipartUpload({
        "Key": s3_key,
        "MultipartUpload": {"Parts": parts},
        "UploadId": upload_id
        }
    );
    return {
        "statusCode": 200,
        "body": {
            "message": "video uploaded successfully"
        }
    };
};

let upload_video_in_parts = inflight (s3_key: str, upload_id: str, part_no: num) => {
    let signed_url = multipartBucket.generatePresignedUrl(
        {
            "Key": s3_key,
            "UploadId": upload_id,
            "PartNumber": part_no
        },
    );
    return signed_url;
};

let handleInitiateMultipartUpload = inflight (req: cloud.ApiRequest) => {
    let json_data = Json.parse(req.body ?? "");
    let s3_key = str.fromJson(json_data["s3_key"]);
    let parts = num.fromJson(json_data["parts"]);
    let response: cloud.ApiResponse = multipartBucket.multipartUpload(s3_key);
    let respose_data = Json.parse(response.body ?? "");
    let upload_id = str.fromJson(respose_data["UploadId"]);
    let urls: MutArray<str> = MutArray<str>[];
    for i in 1..parts {
        let url = upload_video_in_parts(s3_key, upload_id, i);
        urls.push(url);
    } 
    return {
        "status": 200,
        "body": Json.stringify({
            "upload_id": upload_id,
            "upload_urls": urls.copy()
        })
    };
};

api.post("/initiateMultipartUpload", handleInitiateMultipartUpload);
api.post("/completeUpload", handleCompleteUpload);

let website = new cloud.Website(path: "./website");
